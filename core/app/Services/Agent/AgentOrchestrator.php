<?php

namespace App\Services\Agent;

use App\Events\ActionPending;
use App\Llm\ChatDriver;
use App\Llm\LlmException;
use App\Llm\LlmToolCall;
use App\Llm\ResolvedModel;
use App\Models\AuditLog;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\PendingAction;
use App\Models\ToolCallRecord;
use App\Models\ToolPolicy;
use App\Models\User;
use App\Services\Agent\Tools\AgentTool;
use App\Services\Agent\Tools\ToolExecutionResult;
use App\Services\Chat\PreparedTurn;
use Closure;
use Illuminate\Support\Str;
use Throwable;

/**
 * Controlled single-agent loop (max 5 steps):
 * assembles the 4-layer system prompt, enforces PHP tool policies (auto / ask / disabled),
 * pauses non-blockingly on `ask` tools with a 10-minute TTL, logs every tool call & audit trail,
 * and falls back gracefully when a model lacks tool support.
 */
class AgentOrchestrator
{
    public const MAX_STEPS = 5;

    public function __construct(
        private readonly ChatDriver $driver,
        private readonly PromptAssembler $prompts,
        private readonly ToolRegistry $tools,
    ) {}

    /**
     * @param  Closure(string, array<string, mixed>): void  $emit
     * @param  Closure(): bool  $aborted
     */
    public function run(PreparedTurn $turn, Closure $emit, Closure $aborted): OrchestratorResult
    {
        return $this->runLoop(
            user: $turn->user,
            conversation: $turn->conversation,
            assistant: $turn->assistant,
            model: $turn->model,
            messages: $turn->history,
            startStep: 0,
            initialText: '',
            initialInputTokens: 0,
            initialOutputTokens: 0,
            emit: $emit,
            aborted: $aborted,
        );
    }

    /**
     * Resumes a paused `ask` action after the user approves or rejects it.
     *
     * @param  Closure(string, array<string, mixed>): void  $emit
     * @param  Closure(): bool  $aborted
     */
    public function resume(
        User $user,
        Conversation $conversation,
        Message $assistant,
        ResolvedModel $model,
        PendingAction $action,
        bool $approved,
        Closure $emit,
        Closure $aborted,
    ): OrchestratorResult {
        $cont = $action->continuation;

        /** @var list<array<string, mixed>> $messages */
        $messages = is_array($cont['messages'] ?? null) ? array_values($cont['messages']) : [];
        $assistantText = (string) ($cont['assistant_text'] ?? $assistant->content);
        $stepText = (string) ($cont['step_text'] ?? '');
        $stepIndex = (int) ($cont['step'] ?? 0);
        $inputTokens = (int) ($cont['input_tokens'] ?? 0);
        $outputTokens = (int) ($cont['output_tokens'] ?? 0);

        /** @var list<array{tool_call_id: string, tool_name: string, args: array<string, mixed>, result: string}> $toolResults */
        $toolResults = is_array($cont['completed_results'] ?? null) ? array_values($cont['completed_results']) : [];

        /** @var list<array{id: string, name: string, arguments: array<string, mixed>}> $allStepCalls */
        $allStepCalls = is_array($cont['step_tool_calls'] ?? null) ? array_values($cont['step_tool_calls']) : [];

        /** @var list<array{id: string, name: string, arguments: array<string, mixed>}> $remainingCalls */
        $remainingCalls = is_array($cont['remaining_calls'] ?? null) ? array_values($cont['remaining_calls']) : [];

        $tool = $this->tools->find($action->tool_name);

        if ($approved && $tool !== null) {
            $toolResults[] = $this->executeAndRecord(
                user: $user,
                conversation: $conversation,
                assistant: $assistant,
                tool: $tool,
                call: new LlmToolCall($action->tool_call_id, $action->tool_name, $action->arguments),
                mode: ToolPolicy::MODE_ASK,
                auditOkStatus: AuditLog::STATUS_APPROVED,
                emit: $emit,
            );
        } else {
            AuditLog::create([
                'user_id' => $user->id,
                'conversation_id' => $conversation->id,
                'tool_name' => $action->tool_name,
                'mode' => ToolPolicy::MODE_ASK,
                'status' => $approved ? AuditLog::STATUS_ERROR : AuditLog::STATUS_REJECTED,
                'summary' => $action->summary,
                'created_at' => now(),
            ]);

            $toolResults[] = [
                'tool_call_id' => $action->tool_call_id,
                'tool_name' => $action->tool_name,
                'args' => $action->arguments,
                'result' => $approved
                    ? "Tool '{$action->tool_name}' is no longer available."
                    : 'User rejected this action. Acknowledge politely without executing or retrying it.',
            ];
        }

        // Process any remaining tool calls from the same paused step.
        foreach ($remainingCalls as $idx => $rawCall) {
            $nextCall = new LlmToolCall(
                id: (string) $rawCall['id'],
                name: (string) $rawCall['name'],
                arguments: $rawCall['arguments'],
            );

            $outcome = $this->processSingleCall(
                user: $user,
                conversation: $conversation,
                assistant: $assistant,
                call: $nextCall,
                messagesBeforeStep: $messages,
                assistantText: $assistantText,
                stepText: $stepText,
                allStepCalls: $allStepCalls,
                completedResults: $toolResults,
                remainingAfter: array_slice($remainingCalls, $idx + 1),
                stepIndex: $stepIndex,
                inputTokens: $inputTokens,
                outputTokens: $outputTokens,
                emit: $emit,
            );

            if ($outcome instanceof PendingAction) {
                return new OrchestratorResult(
                    text: $assistantText,
                    inputTokens: $inputTokens,
                    outputTokens: $outputTokens,
                    status: 'awaiting_approval',
                    pendingAction: $outcome,
                );
            }

            $toolResults[] = $outcome;
        }

        $messages[] = [
            'role' => 'assistant',
            'content' => $stepText,
            'tool_calls' => $allStepCalls,
        ];
        $messages[] = [
            'role' => 'tool_result',
            'results' => $toolResults,
        ];

        return $this->runLoop(
            user: $user,
            conversation: $conversation,
            assistant: $assistant,
            model: $model,
            messages: $messages,
            startStep: $stepIndex + 1,
            initialText: $assistantText,
            initialInputTokens: $inputTokens,
            initialOutputTokens: $outputTokens,
            emit: $emit,
            aborted: $aborted,
        );
    }

    /**
     * @param  list<array<string, mixed>>  $messages
     * @param  Closure(string, array<string, mixed>): void  $emit
     * @param  Closure(): bool  $aborted
     */
    private function runLoop(
        User $user,
        Conversation $conversation,
        Message $assistant,
        ResolvedModel $model,
        array $messages,
        int $startStep,
        string $initialText,
        int $initialInputTokens,
        int $initialOutputTokens,
        Closure $emit,
        Closure $aborted,
    ): OrchestratorResult {
        $systemPrompt = $this->prompts->assemble($user);
        $toolDefs = $model->supportsTools ? $this->tools->definitionsFor($user) : [];

        $finalText = $initialText;
        $totalInputTokens = $initialInputTokens;
        $totalOutputTokens = $initialOutputTokens;
        $status = 'complete';
        $errorCode = null;
        $retriedWithoutTools = false;

        try {
            for ($step = $startStep; $step < self::MAX_STEPS; $step++) {
                $stepText = '';
                /** @var list<LlmToolCall> $stepToolCalls */
                $stepToolCalls = [];
                $stepInput = 0;
                $stepOutput = 0;

                try {
                    foreach ($this->driver->stream($model, $systemPrompt, $messages, $toolDefs) as $event) {
                        if ($event->isDelta()) {
                            $stepText .= $event->text;
                            $finalText .= $event->text;
                            $emit('delta', ['text' => $event->text]);
                        } elseif ($event->isToolCall() && $event->toolCall !== null) {
                            $stepToolCalls[] = $event->toolCall;
                        } else {
                            $stepInput = $event->inputTokens;
                            $stepOutput = $event->outputTokens;
                        }

                        if ($aborted()) {
                            $status = 'cancelled';
                            break;
                        }
                    }
                } catch (LlmException $e) {
                    if (
                        $step === 0
                        && ! $retriedWithoutTools
                        && $toolDefs !== []
                        && $e->errorCode === LlmException::TOOLS_UNSUPPORTED
                    ) {
                        $retriedWithoutTools = true;
                        $toolDefs = [];
                        $emit('notice', [
                            'code' => 'tools_unsupported_fallback',
                            'message' => __('This model does not support tools. Continuing with standard chat.'),
                        ]);
                        $step--;

                        continue;
                    }

                    throw $e;
                }

                $totalInputTokens += $stepInput;
                $totalOutputTokens += $stepOutput;

                if ($status === 'cancelled' || $stepToolCalls === []) {
                    break;
                }

                $serializedStepCalls = array_map(
                    fn (LlmToolCall $c): array => [
                        'id' => $c->id,
                        'name' => $c->name,
                        'arguments' => $c->arguments,
                    ],
                    $stepToolCalls,
                );

                /** @var list<array{tool_call_id: string, tool_name: string, args: array<string, mixed>, result: string}> $toolResults */
                $toolResults = [];

                foreach ($stepToolCalls as $idx => $call) {
                    $outcome = $this->processSingleCall(
                        user: $user,
                        conversation: $conversation,
                        assistant: $assistant,
                        call: $call,
                        messagesBeforeStep: $messages,
                        assistantText: $finalText,
                        stepText: $stepText,
                        allStepCalls: $serializedStepCalls,
                        completedResults: $toolResults,
                        remainingAfter: array_slice($serializedStepCalls, $idx + 1),
                        stepIndex: $step,
                        inputTokens: $totalInputTokens,
                        outputTokens: $totalOutputTokens,
                        emit: $emit,
                    );

                    if ($outcome instanceof PendingAction) {
                        return new OrchestratorResult(
                            text: $finalText,
                            inputTokens: $totalInputTokens,
                            outputTokens: $totalOutputTokens,
                            status: 'awaiting_approval',
                            pendingAction: $outcome,
                        );
                    }

                    $toolResults[] = $outcome;
                }

                $messages[] = [
                    'role' => 'assistant',
                    'content' => $stepText,
                    'tool_calls' => $serializedStepCalls,
                ];
                $messages[] = [
                    'role' => 'tool_result',
                    'results' => $toolResults,
                ];
            }
        } catch (LlmException $e) {
            $status = 'error';
            $errorCode = $model->isUserKey() && $e->errorCode === LlmException::KEY_INVALID
                ? 'user_key_invalid'
                : $e->errorCode;

            if ($model->isUserKey()) {
                $user->aiKey?->forceFill(['last_error' => $e->userMessage(true)])->save();
            }

            report($e);
            $emit('error', ['code' => $errorCode, 'message' => $e->userMessage($model->isUserKey())]);
        }

        return new OrchestratorResult(
            text: $finalText,
            inputTokens: $totalInputTokens,
            outputTokens: $totalOutputTokens,
            status: $status,
            errorCode: $errorCode,
        );
    }

    /**
     * @param  list<array<string, mixed>>  $messagesBeforeStep
     * @param  list<array{id: string, name: string, arguments: array<string, mixed>}>  $allStepCalls
     * @param  list<array{tool_call_id: string, tool_name: string, args: array<string, mixed>, result: string}>  $completedResults
     * @param  list<array{id: string, name: string, arguments: array<string, mixed>}>  $remainingAfter
     * @param  Closure(string, array<string, mixed>): void  $emit
     * @return PendingAction|array{tool_call_id: string, tool_name: string, args: array<string, mixed>, result: string}
     */
    private function processSingleCall(
        User $user,
        Conversation $conversation,
        Message $assistant,
        LlmToolCall $call,
        array $messagesBeforeStep,
        string $assistantText,
        string $stepText,
        array $allStepCalls,
        array $completedResults,
        array $remainingAfter,
        int $stepIndex,
        int $inputTokens,
        int $outputTokens,
        Closure $emit,
    ): PendingAction|array {
        $tool = $this->tools->find($call->name);
        $mode = $this->tools->resolveMode($call->name, $user->role);

        if ($tool === null || $mode === ToolPolicy::MODE_DISABLED) {
            AuditLog::create([
                'user_id' => $user->id,
                'conversation_id' => $conversation->id,
                'tool_name' => $call->name,
                'mode' => ToolPolicy::MODE_DISABLED,
                'status' => AuditLog::STATUS_DENIED,
                'summary' => 'Tool disabled or unknown',
                'created_at' => now(),
            ]);

            return [
                'tool_call_id' => $call->id,
                'tool_name' => $call->name,
                'args' => $call->arguments,
                'result' => "Tool '{$call->name}' is disabled or not available for your account.",
            ];
        }

        if ($mode === ToolPolicy::MODE_ASK) {
            $summary = $this->describePendingAction($tool, $user, $call->arguments);

            /** @var PendingAction $pending */
            $pending = PendingAction::create([
                'user_id' => $user->id,
                'conversation_id' => $conversation->id,
                'message_id' => $assistant->id,
                'tool_call_id' => $call->id,
                'tool_name' => $tool->name(),
                'arguments' => $call->arguments,
                'title' => $tool->label(),
                'summary' => $summary,
                'continuation' => [
                    'messages' => $messagesBeforeStep,
                    'assistant_text' => $assistantText,
                    'step_text' => $stepText,
                    'step_tool_calls' => $allStepCalls,
                    'completed_results' => $completedResults,
                    'remaining_calls' => $remainingAfter,
                    'step' => $stepIndex,
                    'input_tokens' => $inputTokens,
                    'output_tokens' => $outputTokens,
                ],
                'status' => PendingAction::STATUS_PENDING,
                'expires_at' => now()->addMinutes(PendingAction::TTL_MINUTES),
            ]);

            $emit('action.pending', $pending->toApiArray());
            broadcast(ActionPending::for($pending))->toOthers();

            return $pending;
        }

        return $this->executeAndRecord(
            user: $user,
            conversation: $conversation,
            assistant: $assistant,
            tool: $tool,
            call: $call,
            mode: ToolPolicy::MODE_AUTO,
            auditOkStatus: AuditLog::STATUS_EXECUTED,
            emit: $emit,
        );
    }

    /**
     * @param  Closure(string, array<string, mixed>): void  $emit
     * @return array{tool_call_id: string, tool_name: string, args: array<string, mixed>, result: string}
     */
    private function executeAndRecord(
        User $user,
        Conversation $conversation,
        Message $assistant,
        AgentTool $tool,
        LlmToolCall $call,
        string $mode,
        string $auditOkStatus,
        Closure $emit,
    ): array {
        /** @var ToolCallRecord $record */
        $record = ToolCallRecord::create([
            'conversation_id' => $conversation->id,
            'message_id' => $assistant->id,
            'user_id' => $user->id,
            'tool_name' => $tool->name(),
            'arguments' => $call->arguments,
            'status' => ToolCallRecord::STATUS_OK,
            'latency_ms' => 0,
        ]);

        $emit('tool.start', [
            'tool_call_id' => $record->id,
            'tool' => $tool->name(),
            'label' => $tool->label(),
        ]);

        $startedAt = hrtime(true);
        try {
            $exec = $tool->execute($user, $call->arguments);
        } catch (Throwable $e) {
            report($e);
            $exec = ToolExecutionResult::error(
                'Tool execution failed due to an internal error.',
                __('Tool failed'),
            );
        }
        $latencyMs = (int) ((hrtime(true) - $startedAt) / 1_000_000);

        $record->update([
            'status' => $exec->ok ? ToolCallRecord::STATUS_OK : ToolCallRecord::STATUS_ERROR,
            'result_summary' => $exec->summary,
            'latency_ms' => $latencyMs,
        ]);

        AuditLog::create([
            'user_id' => $user->id,
            'conversation_id' => $conversation->id,
            'tool_name' => $tool->name(),
            'mode' => $mode,
            'status' => $exec->ok ? $auditOkStatus : AuditLog::STATUS_ERROR,
            'summary' => $exec->summary,
            'latency_ms' => $latencyMs,
            'created_at' => now(),
        ]);

        $emit('tool.end', [
            'tool_call_id' => $record->id,
            'tool' => $tool->name(),
            'status' => $record->status,
            'summary' => $exec->summary,
        ]);

        return [
            'tool_call_id' => $call->id,
            'tool_name' => $tool->name(),
            'args' => $call->arguments,
            'result' => $exec->output,
        ];
    }

    /**
     * Builds a concise, human-readable summary for the approval card in the app.
     *
     * @param  array<string, mixed>  $arguments
     */
    private function describePendingAction(AgentTool $tool, User $user, array $arguments): string
    {
        if ($tool->name() === 'delete_note' && is_string($arguments['note_id'] ?? null)) {
            $note = $user->notes()->whereKey($arguments['note_id'])->first();
            if ($note !== null) {
                return __('Permanently delete note ":title".', ['title' => $note->title]);
            }
        }

        if ($tool->name() === 'forget_memory' && is_string($arguments['memory_id'] ?? null)) {
            $memory = $user->memories()->whereKey($arguments['memory_id'])->first();
            if ($memory !== null) {
                return __('Forget memory: ":content".', ['content' => Str::limit($memory->content, 80)]);
            }
        }

        if ($arguments === []) {
            return $tool->description();
        }

        $parts = [];
        foreach ($arguments as $k => $v) {
            $val = is_scalar($v) ? (string) $v : (json_encode($v) ?: '');
            $parts[] = "{$k}: ".Str::limit($val, 60);
        }

        return implode(' · ', $parts);
    }
}

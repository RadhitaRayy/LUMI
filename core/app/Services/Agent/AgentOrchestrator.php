<?php

namespace App\Services\Agent;

use App\Llm\ChatDriver;
use App\Llm\LlmException;
use App\Llm\LlmToolCall;
use App\Models\AuditLog;
use App\Models\ToolCallRecord;
use App\Models\ToolPolicy;
use App\Services\Chat\PreparedTurn;
use Closure;
use Throwable;

/**
 * Controlled single-agent loop (max 5 steps):
 * assembles the 4-layer system prompt, enforces PHP tool policies (auto / ask / disabled),
 * logs every tool call & audit trail, and falls back gracefully when a model lacks tool support.
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
        $systemPrompt = $this->prompts->assemble($turn->user);
        $toolDefs = $turn->model->supportsTools ? $this->tools->definitionsFor($turn->user) : [];

        /** @var list<array<string, mixed>> $messages */
        $messages = $turn->history;

        $finalText = '';
        $totalInputTokens = 0;
        $totalOutputTokens = 0;
        $status = 'complete';
        $errorCode = null;
        $retriedWithoutTools = false;

        try {
            for ($step = 0; $step < self::MAX_STEPS; $step++) {
                $stepText = '';
                /** @var list<LlmToolCall> $stepToolCalls */
                $stepToolCalls = [];
                $stepInput = 0;
                $stepOutput = 0;

                try {
                    foreach ($this->driver->stream($turn->model, $systemPrompt, $messages, $toolDefs) as $event) {
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
                    // Graceful fallback when a model rejects tool definitions on step 0.
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

                // Enforce PHP tool policy for every requested tool call.
                $toolResults = [];
                foreach ($stepToolCalls as $call) {
                    $toolResults[] = $this->handleToolCall($turn, $call, $emit);
                }

                $messages[] = [
                    'role' => 'assistant',
                    'content' => $stepText,
                    'tool_calls' => array_map(
                        fn (LlmToolCall $c): array => [
                            'id' => $c->id,
                            'name' => $c->name,
                            'arguments' => $c->arguments,
                        ],
                        $stepToolCalls,
                    ),
                ];

                $messages[] = [
                    'role' => 'tool_result',
                    'results' => $toolResults,
                ];
            }
        } catch (LlmException $e) {
            $status = 'error';
            $errorCode = $turn->model->isUserKey() && $e->errorCode === LlmException::KEY_INVALID
                ? 'user_key_invalid'
                : $e->errorCode;

            if ($turn->model->isUserKey()) {
                $turn->user->aiKey?->forceFill(['last_error' => $e->userMessage(true)])->save();
            }

            report($e);
            $emit('error', ['code' => $errorCode, 'message' => $e->userMessage($turn->model->isUserKey())]);
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
     * @param  Closure(string, array<string, mixed>): void  $emit
     * @return array{tool_call_id: string, tool_name: string, args: array<string, mixed>, result: string}
     */
    private function handleToolCall(PreparedTurn $turn, LlmToolCall $call, Closure $emit): array
    {
        $tool = $this->tools->find($call->name);
        $mode = $this->tools->resolveMode($call->name, $turn->user->role);

        if ($tool === null || $mode === ToolPolicy::MODE_DISABLED) {
            AuditLog::create([
                'user_id' => $turn->user->id,
                'conversation_id' => $turn->conversation->id,
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
            AuditLog::create([
                'user_id' => $turn->user->id,
                'conversation_id' => $turn->conversation->id,
                'tool_name' => $tool->name(),
                'mode' => ToolPolicy::MODE_ASK,
                'status' => AuditLog::STATUS_DENIED,
                'summary' => 'Requires explicit user approval',
                'created_at' => now(),
            ]);

            return [
                'tool_call_id' => $call->id,
                'tool_name' => $tool->name(),
                'args' => $call->arguments,
                'result' => "Tool '{$tool->name()}' requires explicit user approval and cannot be executed automatically.",
            ];
        }

        /** @var ToolCallRecord $record */
        $record = ToolCallRecord::create([
            'conversation_id' => $turn->conversation->id,
            'message_id' => $turn->assistant->id,
            'user_id' => $turn->user->id,
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
            $exec = $tool->execute($turn->user, $call->arguments);
        } catch (Throwable $e) {
            report($e);
            $exec = Tools\ToolExecutionResult::error(
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
            'user_id' => $turn->user->id,
            'conversation_id' => $turn->conversation->id,
            'tool_name' => $tool->name(),
            'mode' => ToolPolicy::MODE_AUTO,
            'status' => $exec->ok ? AuditLog::STATUS_EXECUTED : AuditLog::STATUS_ERROR,
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
}

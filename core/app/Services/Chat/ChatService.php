<?php

namespace App\Services\Chat;

use App\Events\ActionResolved;
use App\Events\ConversationUpdated;
use App\Events\MessageCreated;
use App\Exceptions\ApiException;
use App\Llm\ModelResolver;
use App\Models\Conversation;
use App\Models\LlmUsage;
use App\Models\Message;
use App\Models\PendingAction;
use App\Models\User;
use App\Services\Agent\AgentOrchestrator;
use App\Services\Agent\OrchestratorResult;
use Closure;
use Illuminate\Support\Str;

/**
 * Runs one chat turn: checks quota, stores messages, runs the AgentOrchestrator, logs usage.
 */
class ChatService
{
    /** How many earlier messages are sent to the model as context. */
    private const HISTORY_LIMIT = 30;

    public function __construct(
        private readonly ModelResolver $resolver,
        private readonly AgentOrchestrator $orchestrator,
    ) {}

    /**
     * Everything that must succeed before the stream starts (errors become normal JSON responses).
     */
    public function prepare(User $user, Conversation $conversation, string $content): PreparedTurn
    {
        $model = $this->resolver->for($user);

        // Answers cut off earlier must not keep counting as "in progress" toward the quota.
        Message::expireStale($user->id);

        if (! $model->isUserKey()) {
            $limit = $user->effectiveDailyQuota();
            if ($user->platformMessagesToday() >= $limit) {
                throw new ApiException('quota_exceeded', __('You have used up today\'s quota. Add your own API key in My AI key, or try again tomorrow.'), 429, [
                    'daily_limit' => $limit,
                ]);
            }
        }

        $history = $conversation->messages()
            ->reorder() // the relation sorts oldest-first; we need the newest N
            ->where('status', 'complete')
            ->latest('created_at')->latest('id')
            ->limit(self::HISTORY_LIMIT)
            ->get(['role', 'content'])
            ->reverse()
            ->map(fn (Message $m) => ['role' => $m->role, 'content' => $m->content])
            ->values()
            ->all();

        $userMessage = $conversation->messages()->create([
            'role' => Message::ROLE_USER,
            'content' => $content,
            'status' => 'complete',
            'key_source' => $model->keySource,
            'provider' => $model->providerName,
            'model' => $model->modelId,
        ]);

        $assistant = $conversation->messages()->create([
            'role' => Message::ROLE_ASSISTANT,
            'content' => '',
            'status' => 'streaming',
            'key_source' => $model->keySource,
            'provider' => $model->providerName,
            'model' => $model->modelId,
        ]);

        $conversation->forceFill([
            'title' => $conversation->title ?? Str::limit(Str::squish($content), 60, '…'),
            'last_message_at' => now(),
        ])->save();

        // Other devices see the question right away; the answer follows when it is finished.
        broadcast(MessageCreated::for($conversation, $userMessage))->toOthers();
        broadcast(ConversationUpdated::for($conversation))->toOthers();

        // Oldest first, ending with the new user message.
        $messages = [...$history, ['role' => Message::ROLE_USER, 'content' => $content]];

        return new PreparedTurn($user, $conversation, $model, $userMessage, $assistant, $messages);
    }

    /**
     * Stream the answer. `$emit(event, data)` writes one SSE event; `$aborted()` reports a client disconnect.
     *
     * @param  Closure(string, array<string, mixed>): void  $emit
     * @param  Closure(): bool  $aborted
     */
    public function stream(PreparedTurn $turn, Closure $emit, Closure $aborted): void
    {
        $emit('message.start', [
            'message_id' => $turn->assistant->id,
            'user_message_id' => $turn->userMessage->id,
            'model' => $turn->model->modelId,
            'key_source' => $turn->model->keySource,
        ]);

        $startedAt = hrtime(true);
        $result = $this->orchestrator->run($turn, $emit, $aborted);

        $this->finalizeAssistant(
            user: $turn->user,
            conversation: $turn->conversation,
            assistant: $turn->assistant,
            modelKeySource: $turn->model->keySource,
            providerName: $turn->model->providerName,
            modelId: $turn->model->modelId,
            result: $result,
            startedAt: $startedAt,
            emit: $emit,
        );
    }

    /**
     * Validates a pending action and marks it approved/rejected before opening the SSE resume stream.
     */
    public function prepareResume(User $user, PendingAction $action, bool $approved): PendingAction
    {
        PendingAction::expireOverdue($user->id);
        $action->refresh();

        if ($action->status === PendingAction::STATUS_EXPIRED || $action->isExpired()) {
            throw new ApiException('action_expired', __('This approval request has expired.'), 410);
        }

        if ($action->status !== PendingAction::STATUS_PENDING) {
            throw new ApiException('action_already_resolved', __('This approval request was already handled.'), 409);
        }

        $action->forceFill([
            'status' => $approved ? PendingAction::STATUS_APPROVED : PendingAction::STATUS_REJECTED,
            'resolved_at' => now(),
        ])->save();

        broadcast(ActionResolved::for($action))->toOthers();

        return $action;
    }

    /**
     * Resumes a resolved `ask` action and streams the remaining orchestrator turn via SSE.
     *
     * @param  Closure(string, array<string, mixed>): void  $emit
     * @param  Closure(): bool  $aborted
     */
    public function streamResume(User $user, PendingAction $action, bool $approved, Closure $emit, Closure $aborted): void
    {
        /** @var Conversation $conversation */
        $conversation = $action->conversation()->firstOrFail();
        /** @var Message $assistant */
        $assistant = $action->message()->firstOrFail();
        $model = $this->resolver->for($user);

        $assistant->update(['status' => 'streaming']);

        $emit('message.start', [
            'message_id' => $assistant->id,
            'model' => $model->modelId,
            'key_source' => $model->keySource,
        ]);

        $startedAt = hrtime(true);
        $result = $this->orchestrator->resume($user, $conversation, $assistant, $model, $action, $approved, $emit, $aborted);

        $this->finalizeAssistant(
            user: $user,
            conversation: $conversation,
            assistant: $assistant,
            modelKeySource: $model->keySource,
            providerName: $model->providerName,
            modelId: $model->modelId,
            result: $result,
            startedAt: $startedAt,
            emit: $emit,
        );
    }

    /**
     * @param  Closure(string, array<string, mixed>): void  $emit
     */
    private function finalizeAssistant(
        User $user,
        Conversation $conversation,
        Message $assistant,
        string $modelKeySource,
        string $providerName,
        string $modelId,
        OrchestratorResult $result,
        int $startedAt,
        Closure $emit,
    ): void {
        $assistant->update([
            'content' => $result->text,
            'status' => $result->status,
            'input_tokens' => $result->inputTokens ?: null,
            'output_tokens' => $result->outputTokens ?: null,
            'error_code' => $result->errorCode,
        ]);

        $assistant->load(['toolCalls', 'pendingActions']);

        $conversation->forceFill(['last_message_at' => now()])->save();

        broadcast(MessageCreated::for($conversation, $assistant))->toOthers();
        broadcast(ConversationUpdated::for($conversation))->toOthers();

        if ($result->status !== 'awaiting_approval') {
            LlmUsage::create([
                'user_id' => $user->id,
                'conversation_id' => $conversation->id,
                'message_id' => $assistant->id,
                'key_source' => $modelKeySource,
                'provider' => $providerName,
                'model' => $modelId,
                'input_tokens' => $result->inputTokens,
                'output_tokens' => $result->outputTokens,
                'latency_ms' => (int) ((hrtime(true) - $startedAt) / 1_000_000),
                'status' => $result->status,
                'error_code' => $result->errorCode,
            ]);
        }

        if ($result->status === 'complete') {
            $emit('message.end', [
                'message_id' => $assistant->id,
                'input_tokens' => $result->inputTokens,
                'output_tokens' => $result->outputTokens,
            ]);
        }
    }
}

<?php

namespace App\Services\Chat;

use App\Events\ConversationUpdated;
use App\Events\MessageCreated;
use App\Exceptions\ApiException;
use App\Llm\ModelResolver;
use App\Models\Conversation;
use App\Models\LlmUsage;
use App\Models\Message;
use App\Models\User;
use App\Services\Agent\AgentOrchestrator;
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

        $turn->assistant->update([
            'content' => $result->text,
            'status' => $result->status,
            'input_tokens' => $result->inputTokens ?: null,
            'output_tokens' => $result->outputTokens ?: null,
            'error_code' => $result->errorCode,
        ]);

        $turn->assistant->load('toolCalls');

        $turn->conversation->forceFill(['last_message_at' => now()])->save();

        broadcast(MessageCreated::for($turn->conversation, $turn->assistant))->toOthers();
        broadcast(ConversationUpdated::for($turn->conversation))->toOthers();

        LlmUsage::create([
            'user_id' => $turn->user->id,
            'conversation_id' => $turn->conversation->id,
            'message_id' => $turn->assistant->id,
            'key_source' => $turn->model->keySource,
            'provider' => $turn->model->providerName,
            'model' => $turn->model->modelId,
            'input_tokens' => $result->inputTokens,
            'output_tokens' => $result->outputTokens,
            'latency_ms' => (int) ((hrtime(true) - $startedAt) / 1_000_000),
            'status' => $result->status,
            'error_code' => $result->errorCode,
        ]);

        if ($result->status === 'complete') {
            $emit('message.end', [
                'message_id' => $turn->assistant->id,
                'input_tokens' => $result->inputTokens,
                'output_tokens' => $result->outputTokens,
            ]);
        }
    }
}

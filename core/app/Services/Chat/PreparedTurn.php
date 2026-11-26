<?php

namespace App\Services\Chat;

use App\Llm\ResolvedModel;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;

final readonly class PreparedTurn
{
    /**
     * @param  list<array{role: string, content: string}>  $history
     */
    public function __construct(
        public User $user,
        public Conversation $conversation,
        public ResolvedModel $model,
        public Message $userMessage,
        public Message $assistant,
        public array $history,
    ) {}
}

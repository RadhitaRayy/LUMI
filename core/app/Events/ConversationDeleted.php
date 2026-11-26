<?php

namespace App\Events;

use App\Models\Conversation;

class ConversationDeleted extends UserChannelEvent
{
    public static function for(Conversation $conversation): self
    {
        return new self($conversation->user_id, ['id' => $conversation->id]);
    }

    public function broadcastAs(): string
    {
        return 'conversation.deleted';
    }
}

<?php

namespace App\Events;

use App\Http\Resources\ConversationResource;
use App\Models\Conversation;

class ConversationCreated extends UserChannelEvent
{
    public static function for(Conversation $conversation): self
    {
        return new self($conversation->user_id, ['conversation' => ConversationResource::summary($conversation)]);
    }

    public function broadcastAs(): string
    {
        return 'conversation.created';
    }
}

<?php

namespace App\Events;

use App\Http\Resources\ConversationResource;
use App\Models\Conversation;

/** Title changed or a message finished (carries the new `last_message_at`). */
class ConversationUpdated extends UserChannelEvent
{
    public static function for(Conversation $conversation): self
    {
        return new self($conversation->user_id, ['conversation' => ConversationResource::summary($conversation)]);
    }

    public function broadcastAs(): string
    {
        return 'conversation.updated';
    }
}

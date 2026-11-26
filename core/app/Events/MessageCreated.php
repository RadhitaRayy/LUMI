<?php

namespace App\Events;

use App\Http\Resources\MessageResource;
use App\Models\Conversation;
use App\Models\Message;

/** A user message was saved, or an assistant answer finished (complete, error or cancelled). */
class MessageCreated extends UserChannelEvent
{
    public static function for(Conversation $conversation, Message $message): self
    {
        return new self($conversation->user_id, [
            'conversation_id' => $conversation->id,
            'message' => (new MessageResource($message))->resolve(),
        ]);
    }

    public function broadcastAs(): string
    {
        return 'message.created';
    }
}

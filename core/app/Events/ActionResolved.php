<?php

namespace App\Events;

use App\Models\PendingAction;

class ActionResolved extends UserChannelEvent
{
    public static function for(PendingAction $action): self
    {
        return new self($action->user_id, [
            'action_id' => $action->id,
            'conversation_id' => $action->conversation_id,
            'message_id' => $action->message_id,
            'status' => $action->status,
        ]);
    }

    public function broadcastAs(): string
    {
        return 'action.resolved';
    }
}

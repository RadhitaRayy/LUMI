<?php

namespace App\Events;

use App\Models\PendingAction;

class ActionPending extends UserChannelEvent
{
    public static function for(PendingAction $action): self
    {
        return new self($action->user_id, [
            'action' => $action->toApiArray(),
        ]);
    }

    public function broadcastAs(): string
    {
        return 'action.pending';
    }
}

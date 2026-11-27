<?php

namespace App\Events;

use App\Models\UserMemory;

class MemoryChanged extends UserChannelEvent
{
    public static function created(UserMemory $memory): self
    {
        return new self($memory->user_id, [
            'action' => 'created',
            'memory' => $memory->toApiArray(),
        ]);
    }

    public static function updated(UserMemory $memory): self
    {
        return new self($memory->user_id, [
            'action' => 'updated',
            'memory' => $memory->toApiArray(),
        ]);
    }

    public static function deleted(int $userId, string $id): self
    {
        return new self($userId, [
            'action' => 'deleted',
            'id' => $id,
        ]);
    }

    public function broadcastAs(): string
    {
        return 'memory.changed';
    }
}

<?php

namespace App\Events;

use App\Models\UserNote;

class NoteChanged extends UserChannelEvent
{
    public static function created(UserNote $note): self
    {
        return new self($note->user_id, [
            'action' => 'created',
            'note' => $note->toApiArray(),
        ]);
    }

    public static function updated(UserNote $note): self
    {
        return new self($note->user_id, [
            'action' => 'updated',
            'note' => $note->toApiArray(),
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
        return 'note.changed';
    }
}

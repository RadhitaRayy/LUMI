<?php

namespace App\Events;

use App\Models\UserPersona;

class PersonaUpdated extends UserChannelEvent
{
    public static function for(UserPersona $persona): self
    {
        return new self($persona->user_id, [
            'persona' => $persona->toApiArray(),
        ]);
    }

    public function broadcastAs(): string
    {
        return 'persona.updated';
    }
}

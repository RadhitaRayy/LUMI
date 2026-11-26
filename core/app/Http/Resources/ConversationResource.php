<?php

namespace App\Http\Resources;

use App\Models\Conversation;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Conversation */
class ConversationResource extends JsonResource
{
    /**
     * The conversation without its messages (for lists and realtime events).
     *
     * @return array<string, mixed>
     */
    public static function summary(Conversation $conversation): array
    {
        return (new self($conversation->withoutRelations()))->resolve();
    }

    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'last_message_at' => $this->last_message_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'messages' => MessageResource::collection($this->whenLoaded('messages')),
        ];
    }
}

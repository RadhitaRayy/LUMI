<?php

namespace App\Http\Resources;

use App\Models\Message;
use App\Models\ToolCallRecord;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Message */
class MessageResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'conversation_id' => $this->conversation_id,
            'role' => $this->role,
            'content' => $this->content,
            'status' => $this->status,
            'model' => $this->model,
            'key_source' => $this->key_source,
            'error_code' => $this->error_code,
            'tool_calls' => $this->relationLoaded('toolCalls')
                ? $this->toolCalls->map(fn (ToolCallRecord $t) => $t->toApiArray())->values()->all()
                : [],
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}

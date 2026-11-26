<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin User */
class UserResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'email_verified' => $this->hasVerifiedEmail(),
            'role' => $this->role->value,
            // Phase 1 later: 'user' once the user has their own AI key.
            'ai_key_source' => 'platform',
            'quota' => [
                'daily_limit' => $this->effectiveDailyQuota(),
            ],
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}

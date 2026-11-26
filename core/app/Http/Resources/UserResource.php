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
            'ai_key_source' => $this->activeAiKey() !== null ? 'user' : 'platform',
            // Quota only applies to messages sent with the platform key.
            'quota' => [
                'daily_limit' => $limit = $this->effectiveDailyQuota(),
                'used_today' => $used = $this->platformMessagesToday(),
                'remaining' => max(0, $limit - $used),
            ],
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}

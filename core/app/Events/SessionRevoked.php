<?php

namespace App\Events;

/**
 * Device tokens were revoked (signed out from another device, or the password changed).
 * A device whose own `token_id` is listed goes back to the sign-in screen.
 */
class SessionRevoked extends UserChannelEvent
{
    /**
     * @param  array<array-key, int|string>  $tokenIds  ids of personal_access_tokens rows
     */
    public static function for(int $userId, array $tokenIds): self
    {
        return new self($userId, ['token_ids' => array_values(array_map(intval(...), $tokenIds))]);
    }

    public function broadcastAs(): string
    {
        return 'session.revoked';
    }
}

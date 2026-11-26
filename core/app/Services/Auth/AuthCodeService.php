<?php

namespace App\Services\Auth;

use App\Enums\AuthCodePurpose;
use App\Exceptions\ApiException;
use App\Models\AuthCode;
use App\Models\User;
use App\Notifications\AuthCodeNotification;
use Illuminate\Support\Facades\Hash;

/**
 * Issues and checks the 6-digit codes sent by email.
 */
class AuthCodeService
{
    public const TTL_MINUTES = 15;

    public const MAX_ATTEMPTS = 5;

    /** Create a fresh code (invalidating older ones), email it, and return it. */
    public function send(User $user, AuthCodePurpose $purpose): string
    {
        $code = str_pad((string) random_int(0, 999_999), 6, '0', STR_PAD_LEFT);

        $user->authCodes()
            ->where('purpose', $purpose)
            ->whereNull('used_at')
            ->update(['used_at' => now()]);

        $user->authCodes()->create([
            'purpose' => $purpose,
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addMinutes(self::TTL_MINUTES),
        ]);

        $user->notify(new AuthCodeNotification($code, $purpose, self::TTL_MINUTES));

        return $code;
    }

    /**
     * Consume a code or throw an ApiException describing why it was refused.
     */
    public function consume(User $user, AuthCodePurpose $purpose, string $code): void
    {
        /** @var AuthCode|null $authCode */
        $authCode = $user->authCodes()
            ->where('purpose', $purpose)
            ->whereNull('used_at')
            ->latest('id')
            ->first();

        if ($authCode === null) {
            throw new ApiException('code_invalid', 'Kode tidak valid. Minta kode baru.', 422);
        }

        if ($authCode->expires_at->isPast()) {
            throw new ApiException('code_expired', 'Kode sudah kedaluwarsa. Minta kode baru.', 422);
        }

        if ($authCode->attempts >= self::MAX_ATTEMPTS) {
            throw new ApiException('code_attempts_exceeded', 'Terlalu banyak percobaan. Minta kode baru.', 429);
        }

        if (! Hash::check($code, $authCode->code_hash)) {
            $authCode->increment('attempts');
            $left = max(0, self::MAX_ATTEMPTS - $authCode->attempts);

            throw new ApiException('code_invalid', 'Kode salah.', 422, ['attempts_left' => $left]);
        }

        $authCode->update(['used_at' => now()]);
    }
}

<?php

use App\Enums\AuthCodePurpose;
use App\Models\User;
use App\Notifications\AuthCodeNotification;
use Illuminate\Support\Facades\Notification;

/** Valid body for POST /api/v1/auth/register. */
function registerPayload(array $overrides = []): array
{
    return array_merge([
        'name' => 'Rayy',
        'email' => 'rayy@example.com',
        'password' => 'rahasia123',
        'device_name' => 'Galaxy A56',
    ], $overrides);
}

/** The most recent code emailed to the user for the given purpose. */
function lastSentCode(User $user, AuthCodePurpose $purpose): string
{
    $code = null;

    Notification::assertSentTo($user, AuthCodeNotification::class, function (AuthCodeNotification $n) use (&$code, $purpose) {
        if ($n->purpose !== $purpose) {
            return false;
        }
        $code = $n->code;

        return true;
    });

    return $code;
}

/** A user with a real Sanctum token (so "this device" checks work). */
function userWithToken(array $attributes = [], string $device = 'Galaxy A56'): array
{
    $user = User::factory()->create($attributes);

    return [$user, $user->createToken($device)->plainTextToken];
}

<?php

use App\Enums\AuthCodePurpose;
use App\Llm\ChatDriver;
use App\Llm\FakeChatDriver;
use App\Models\LlmModel;
use App\Models\LlmProvider;
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

/** Configure a platform provider + default model (the owner's key). */
function withPlatformModel(string $modelId = 'meta-llama/llama-3.3-70b-instruct:free'): LlmModel
{
    $provider = LlmProvider::create([
        'name' => 'OpenRouter',
        'driver' => 'openrouter',
        'api_key' => 'sk-or-platform-key-1234',
        'is_enabled' => true,
    ]);

    return $provider->models()->create([
        'model_id' => $modelId,
        'label' => 'Llama free',
        'is_default' => true,
        'is_enabled' => true,
    ]);
}

/** Swap the real LLM driver for a scripted one. */
function fakeLlm(...$args): FakeChatDriver
{
    $fake = new FakeChatDriver(...$args);
    app()->instance(ChatDriver::class, $fake);

    return $fake;
}

/**
 * Parse an SSE body into a list of [event, data].
 *
 * @return list<array{0: string, 1: array<string, mixed>}>
 */
function sseEvents(string $body): array
{
    $events = [];
    foreach (preg_split("/\n\n/", trim($body)) as $block) {
        if (preg_match('/^event: (.+)\ndata: (.+)$/s', trim($block), $m)) {
            $events[] = [$m[1], json_decode($m[2], true)];
        }
    }

    return $events;
}

/** A user with a real Sanctum token (so "this device" checks work). */
function userWithToken(array $attributes = [], string $device = 'Galaxy A56'): array
{
    $user = User::factory()->create($attributes);

    return [$user, $user->createToken($device)->plainTextToken];
}

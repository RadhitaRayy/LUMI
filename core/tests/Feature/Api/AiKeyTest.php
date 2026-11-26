<?php

require_once __DIR__.'/helpers.php';

use App\Llm\LlmException;
use App\Models\UserAiKey;
use Illuminate\Support\Facades\DB;

function aiKeyPayload(array $overrides = []): array
{
    return array_merge([
        'driver' => 'openrouter',
        'api_key' => 'sk-or-v1-my-own-secret-abcd',
        'model_id' => 'meta-llama/llama-3.3-70b-instruct:free',
    ], $overrides);
}

it('saves a working key after a test request and never returns it', function () {
    $fake = fakeLlm();
    [$user, $token] = userWithToken();

    $response = $this->withToken($token)->putJson('/api/v1/me/ai-key', aiKeyPayload())
        ->assertOk()
        ->assertJsonPath('ai_key.key_last4', 'abcd')
        ->assertJsonPath('ai_key.is_active', true);

    expect($response->getContent())->not->toContain('my-own-secret')
        ->and($fake->pings[0]->apiKey)->toBe('sk-or-v1-my-own-secret-abcd');

    // Stored encrypted, readable through the model only.
    expect(DB::table('user_ai_keys')->value('api_key'))->not->toContain('my-own-secret')
        ->and($user->aiKey->api_key)->toBe('sk-or-v1-my-own-secret-abcd');

    $this->withToken($token)->getJson('/api/v1/me/ai-key')
        ->assertOk()->assertJsonMissingPath('ai_key.api_key');
});

it('refuses a key the provider rejects and stores nothing', function () {
    fakeLlm(failPingWith: new LlmException(LlmException::KEY_INVALID, '401 Unauthorized'));
    [, $token] = userWithToken();

    $this->withToken($token)->putJson('/api/v1/me/ai-key', aiKeyPayload())
        ->assertUnprocessable()
        ->assertJsonPath('code', 'ai_key_invalid')
        ->assertJsonPath('reason', 'key_invalid');

    expect(UserAiKey::count())->toBe(0);
});

it('needs a base URL for OpenAI-compatible providers like NVIDIA NIM', function () {
    fakeLlm();
    [$user, $token] = userWithToken();

    $this->withToken($token)->putJson('/api/v1/me/ai-key', aiKeyPayload(['driver' => 'openai_compatible']))
        ->assertUnprocessable()->assertJsonValidationErrors('base_url');

    $this->withToken($token)->putJson('/api/v1/me/ai-key', aiKeyPayload([
        'driver' => 'openai_compatible',
        'base_url' => 'https://integrate.api.nvidia.com/v1/',
        'model_id' => 'meta/llama-3.1-8b-instruct',
    ]))->assertOk()->assertJsonPath('ai_key.base_url', 'https://integrate.api.nvidia.com/v1');
});

it('switches between personal key and platform quota', function () {
    fakeLlm();
    [, $token] = userWithToken();
    $this->withToken($token)->putJson('/api/v1/me/ai-key', aiKeyPayload())->assertOk();
    $this->withToken($token)->getJson('/api/v1/me')->assertJsonPath('user.ai_key_source', 'user');

    $this->withToken($token)->patchJson('/api/v1/me/ai-key', ['is_active' => false])
        ->assertOk()->assertJsonPath('ai_key.is_active', false);
    $this->withToken($token)->getJson('/api/v1/me')->assertJsonPath('user.ai_key_source', 'platform');

    $this->withToken($token)->deleteJson('/api/v1/me/ai-key')->assertOk();
    $this->withToken($token)->getJson('/api/v1/me/ai-key')->assertOk()->assertJsonPath('ai_key', null);
});

it('re-tests the stored key and records failures', function () {
    $fake = fakeLlm();
    [$user, $token] = userWithToken();
    $this->withToken($token)->putJson('/api/v1/me/ai-key', aiKeyPayload())->assertOk();

    $this->withToken($token)->postJson('/api/v1/me/ai-key/test')->assertOk()->assertJsonPath('ai_key.last_error', null);

    $fake->failPingWith = new LlmException(LlmException::KEY_INVALID, '401');
    $this->withToken($token)->postJson('/api/v1/me/ai-key/test')
        ->assertUnprocessable()->assertJsonPath('code', 'ai_key_invalid');

    expect($user->aiKey->fresh()->last_error)->not->toBeNull();
});

it('accepts a key when the model is only rate-limited', function () {
    fakeLlm(failPingWith: new LlmException(LlmException::RATE_LIMITED, '429 from upstream'));
    [, $token] = userWithToken();

    $this->withToken($token)->putJson('/api/v1/me/ai-key', aiKeyPayload())
        ->assertOk()->assertJsonPath('ai_key.key_last4', 'abcd');

    $this->withToken($token)->postJson('/api/v1/me/ai-key/test')
        ->assertOk()->assertJsonPath('ai_key.last_error', null);
});

it('says so when there is no key to test', function () {
    fakeLlm();
    [, $token] = userWithToken();

    $this->withToken($token)->postJson('/api/v1/me/ai-key/test')
        ->assertNotFound()->assertJsonPath('code', 'ai_key_missing');
});

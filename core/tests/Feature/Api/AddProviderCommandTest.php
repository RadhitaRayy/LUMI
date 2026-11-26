<?php

require_once __DIR__.'/helpers.php';

use App\Llm\LlmException;
use App\Models\LlmModel;
use App\Models\LlmProvider;

const KEY_PROMPT = 'API key (hidden; paste with right-click)';

it('tests the key and makes the model the default', function () {
    $fake = fakeLlm();

    $this->artisan('lumi:add-provider', ['driver' => 'openrouter', 'model' => 'meta-llama/llama-3.3-70b-instruct:free'])
        ->expectsQuestion(KEY_PROMPT, 'sk-or-v1-abcdefghijklmnopqrstuvwxyz1234')
        ->expectsOutput('Got a key of 39 characters ending in …1234.')
        ->assertSuccessful();

    expect($fake->pings[0]->apiKey)->toBe('sk-or-v1-abcdefghijklmnopqrstuvwxyz1234')
        ->and(LlmProvider::sole()->api_key)->toBe('sk-or-v1-abcdefghijklmnopqrstuvwxyz1234')
        ->and(LlmModel::platformDefault()?->model_id)->toBe('meta-llama/llama-3.3-70b-instruct:free');
});

it('asks again when the paste did not go through', function () {
    $fake = fakeLlm();

    $this->artisan('lumi:add-provider', ['driver' => 'openrouter', 'model' => 'x/y:free'])
        ->expectsQuestion(KEY_PROMPT, 'v')
        ->expectsOutputToContain('does not look like an API key (1 characters)')
        ->expectsQuestion(KEY_PROMPT, "sk-or-v1-abc\u{200B}defghijklmnopqrstuvwxyz")
        ->expectsOutputToContain('with spaces or hidden characters')
        ->expectsQuestion(KEY_PROMPT, 'sk-or-v1-abcdefghijklmnopqrstuvwxyz1234')
        ->assertSuccessful();

    expect($fake->pings)->toHaveCount(1);
});

it('gives up after three bad keys without calling the provider', function () {
    $fake = fakeLlm();

    $this->artisan('lumi:add-provider', ['driver' => 'openrouter', 'model' => 'x/y:free'])
        ->expectsQuestion(KEY_PROMPT, '')
        ->expectsQuestion(KEY_PROMPT, 'v')
        ->expectsQuestion(KEY_PROMPT, 'short')
        ->expectsOutput('No usable API key given.')
        ->assertFailed();

    expect($fake->pings)->toBeEmpty()->and(LlmProvider::count())->toBe(0);
});

it('saves the key when the model is only rate-limited', function () {
    fakeLlm(failPingWith: new LlmException(LlmException::RATE_LIMITED, '429'));

    $this->artisan('lumi:add-provider', ['driver' => 'openrouter', 'model' => 'google/gemma-4-31b-it:free'])
        ->expectsQuestion(KEY_PROMPT, 'sk-or-v1-abcdefghijklmnopqrstuvwxyz1234')
        ->expectsOutputToContain('Key accepted, but the model is rate-limited')
        ->assertSuccessful();

    expect(LlmModel::platformDefault()?->model_id)->toBe('google/gemma-4-31b-it:free');
});

it('stops when the provider rejects the key', function () {
    fakeLlm(failPingWith: new LlmException(LlmException::KEY_INVALID, '401'));

    $this->artisan('lumi:add-provider', ['driver' => 'openrouter', 'model' => 'x/y:free'])
        ->expectsQuestion(KEY_PROMPT, 'sk-or-v1-abcdefghijklmnopqrstuvwxyz1234')
        ->expectsOutputToContain('Provider refused the test (key_invalid)')
        ->assertFailed();

    expect(LlmProvider::count())->toBe(0);
});

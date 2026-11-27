<?php

require_once __DIR__.'/helpers.php';

use App\Llm\LlmException;
use App\Models\AppSetting;
use App\Models\Conversation;
use App\Models\LlmUsage;
use App\Models\Message;

describe('conversations', function () {
    it('creates, lists, shows, renames and deletes conversations', function () {
        [$user, $token] = userWithToken();

        $id = $this->withToken($token)->postJson('/api/v1/conversations', ['title' => 'Ide konten'])
            ->assertCreated()->json('data.id');

        $this->withToken($token)->getJson('/api/v1/conversations')
            ->assertOk()->assertJsonPath('data.0.id', $id);

        $this->withToken($token)->getJson("/api/v1/conversations/{$id}")
            ->assertOk()->assertJsonPath('data.title', 'Ide konten')->assertJsonPath('data.messages', []);

        $this->withToken($token)->patchJson("/api/v1/conversations/{$id}", ['title' => 'Ide video'])
            ->assertOk()->assertJsonPath('data.title', 'Ide video');

        $this->withToken($token)->deleteJson("/api/v1/conversations/{$id}")->assertOk();
        expect(Conversation::find($id))->toBeNull();
    });

    it('searches titles and message text', function () {
        [$user, $token] = userWithToken();
        $match = $user->conversations()->create(['title' => 'Restart bot Discord']);
        $user->conversations()->create(['title' => 'Belanja bulanan']);
        $byText = $user->conversations()->create(['title' => 'Lain']);
        $byText->messages()->create(['role' => 'user', 'content' => 'cek log DISCORD dong']);

        $ids = collect($this->withToken($token)->getJson('/api/v1/conversations?q=discord')->json('data'))->pluck('id');

        expect($ids->all())->toEqualCanonicalizing([$match->id, $byText->id]);
    });

    it("hides other people's conversations", function () {
        [, $token] = userWithToken();
        [$other] = userWithToken(['email' => 'lain@example.com']);
        $theirs = $other->conversations()->create(['title' => 'Rahasia']);

        $this->withToken($token)->getJson("/api/v1/conversations/{$theirs->id}")->assertNotFound();
        $this->withToken($token)->deleteJson("/api/v1/conversations/{$theirs->id}")->assertNotFound();
        $this->withToken($token)->postJson("/api/v1/conversations/{$theirs->id}/messages", ['content' => 'hai'])->assertNotFound();
        expect(collect($this->withToken($token)->getJson('/api/v1/conversations')->json('data')))->toBeEmpty();
    });

    it('requires a verified email', function () {
        [, $token] = userWithToken(['email_verified_at' => null]);

        $this->withToken($token)->getJson('/api/v1/conversations')
            ->assertForbidden()->assertJsonPath('code', 'email_unverified');
    });
});

describe('chat streaming', function () {
    it('streams the answer, saves both messages and logs usage', function () {
        withPlatformModel();
        $fake = fakeLlm(['Halo', ', aku ', 'Lumi.']);
        [$user, $token] = userWithToken(['name' => 'Rayy']);
        $conversation = $user->conversations()->create();

        $response = $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'Halo Lumi, kenalan dong']);

        $response->assertOk()->assertHeader('Content-Type', 'text/event-stream; charset=UTF-8');
        $events = sseEvents($response->streamedContent());

        expect(array_column($events, 0))->toBe(['message.start', 'delta', 'delta', 'delta', 'message.end'])
            ->and($events[0][1]['key_source'])->toBe('platform')
            ->and(implode('', array_map(fn ($e) => $e[1]['text'], array_slice($events, 1, 3))))->toBe('Halo, aku Lumi.');

        $assistant = Message::find($events[0][1]['message_id']);
        expect($assistant->content)->toBe('Halo, aku Lumi.')
            ->and($assistant->status)->toBe('complete')
            ->and($assistant->output_tokens)->toBe(5)
            ->and($conversation->fresh()->title)->toBe('Halo Lumi, kenalan dong')
            ->and($conversation->messages()->where('role', 'user')->value('content'))->toBe('Halo Lumi, kenalan dong');

        $usage = LlmUsage::sole();
        expect($usage->key_source)->toBe('platform')->and($usage->status)->toBe('complete')->and($usage->input_tokens)->toBe(12);

        expect($fake->calls[0]['model']->apiKey)->toBe('sk-or-platform-key-1234')
            ->and($fake->calls[0]['system'])->toContain('Nama pengguna: Rayy');
    });

    it('sends earlier complete messages as context, oldest first', function () {
        withPlatformModel();
        $fake = fakeLlm(['ok']);
        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create(['title' => 'Bot']);
        $conversation->messages()->create(['role' => 'user', 'content' => 'bot jalan?']);
        $this->travel(1)->seconds();
        $conversation->messages()->create(['role' => 'assistant', 'content' => 'jalan semua']);
        $this->travel(1)->seconds();
        $conversation->messages()->create(['role' => 'assistant', 'content' => 'setengah jadi', 'status' => 'error']);
        $this->travel(1)->seconds();

        $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'restart discord'])
            ->assertOk()->streamedContent();

        expect($fake->calls[0]['messages'])->toBe([
            ['role' => 'user', 'content' => 'bot jalan?'],
            ['role' => 'assistant', 'content' => 'jalan semua'],
            ['role' => 'user', 'content' => 'restart discord'],
        ]);
    });

    it('explains when no AI model is configured yet', function () {
        fakeLlm();
        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();

        $this->withToken($token)->postJson("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'hai'])
            ->assertStatus(503)->assertJsonPath('code', 'no_model_configured');

        expect(Message::count())->toBe(0);
    });

    it('stops platform-key chat when the daily quota is used up', function () {
        withPlatformModel();
        fakeLlm(['ok']);
        AppSetting::current()->update(['default_daily_quota' => 2]);
        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();

        foreach (range(1, 2) as $_) {
            $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'hai'])
                ->assertOk()->streamedContent();
        }

        $this->withToken($token)->postJson("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'hai lagi'])
            ->assertStatus(429)
            ->assertJsonPath('code', 'quota_exceeded')
            ->assertJsonPath('daily_limit', 2);

        $this->withToken($token)->getJson('/api/v1/me')
            ->assertJsonPath('user.quota.used_today', 2)
            ->assertJsonPath('user.quota.remaining', 0);
    });

    it('does not charge the quota for answers the provider failed to give', function () {
        withPlatformModel();
        fakeLlm([], failWith: new LlmException(LlmException::RATE_LIMITED, '429'));
        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();

        $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'hai'])
            ->assertOk()->streamedContent();

        $this->withToken($token)->getJson('/api/v1/me')->assertJsonPath('user.quota.used_today', 0);
    });

    it('marks answers that were cut off as failed, so they stop counting and stop "typing"', function () {
        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create(['title' => 'Bot']);
        $stale = $conversation->messages()->create(['role' => 'assistant', 'content' => '', 'status' => 'streaming', 'key_source' => 'platform']);
        $stale->forceFill(['updated_at' => now()->subMinutes(10)])->saveQuietly();
        $live = $conversation->messages()->create(['role' => 'assistant', 'content' => '', 'status' => 'streaming', 'key_source' => 'platform']);

        $this->withToken($token)->getJson("/api/v1/conversations/{$conversation->id}")->assertOk();

        expect($stale->fresh()->status)->toBe('error')
            ->and($stale->fresh()->error_code)->toBe('interrupted')
            ->and($live->fresh()->status)->toBe('streaming');
    });

    it('keeps counting the quota after the conversation is deleted', function () {
        withPlatformModel();
        fakeLlm(['ok']);
        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();

        $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'hai'])
            ->assertOk()->streamedContent();
        $this->withToken($token)->deleteJson("/api/v1/conversations/{$conversation->id}")->assertOk();

        $this->withToken($token)->getJson('/api/v1/me')->assertJsonPath('user.quota.used_today', 1);
    });

    it('counts answers that are still streaming', function () {
        withPlatformModel();
        [$user] = userWithToken();
        $user->conversations()->create()->messages()->create([
            'role' => 'assistant', 'content' => '', 'status' => 'streaming', 'key_source' => 'platform',
        ]);

        expect($user->platformMessagesToday())->toBe(1);
    });

    it("uses the user's own key and does not count it against the quota", function () {
        withPlatformModel();
        $fake = fakeLlm(['pakai key sendiri']);
        AppSetting::current()->update(['default_daily_quota' => 0]);
        [$user, $token] = userWithToken();
        $user->aiKey()->create([
            'driver' => 'openai_compatible',
            'base_url' => 'https://integrate.api.nvidia.com/v1',
            'api_key' => 'nvapi-user-own-key-9876',
            'key_last4' => '9876',
            'model_id' => 'meta/llama-3.1-8b-instruct',
        ]);
        $conversation = $user->conversations()->create();

        $events = sseEvents($this->withToken($token)
            ->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'hai'])
            ->assertOk()->streamedContent());

        expect($events[0][1]['key_source'])->toBe('user')
            ->and($fake->calls[0]['model']->apiKey)->toBe('nvapi-user-own-key-9876')
            ->and($fake->calls[0]['model']->baseUrl)->toBe('https://integrate.api.nvidia.com/v1')
            ->and(LlmUsage::sole()->key_source)->toBe('user');

        $this->withToken($token)->getJson('/api/v1/me')
            ->assertJsonPath('user.ai_key_source', 'user')
            ->assertJsonPath('user.quota.used_today', 0);
    });

    it('reports provider failures in the stream and keeps the partial answer', function () {
        withPlatformModel();
        fakeLlm(['Sebentar'], failWith: new LlmException(LlmException::RATE_LIMITED, '429 from provider'));
        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();

        $events = sseEvents($this->withToken($token)
            ->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'hai'])
            ->assertOk()->streamedContent());

        expect(array_column($events, 0))->toBe(['message.start', 'delta', 'error'])
            ->and($events[2][1]['code'])->toBe('provider_rate_limited');

        $assistant = Message::where('role', 'assistant')->sole();
        expect($assistant->status)->toBe('error')
            ->and($assistant->content)->toBe('Sebentar')
            ->and(LlmUsage::sole()->error_code)->toBe('provider_rate_limited');
    });

    it('flags a rejected personal key so the user can fix it', function () {
        fakeLlm([], failWith: new LlmException(LlmException::KEY_INVALID, '401'));
        [$user, $token] = userWithToken();
        $user->aiKey()->create([
            'driver' => 'openrouter', 'api_key' => 'sk-or-bad-key-0000', 'key_last4' => '0000', 'model_id' => 'x/y:free',
        ]);
        $conversation = $user->conversations()->create();

        $events = sseEvents($this->withToken($token)
            ->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'hai'])
            ->streamedContent());

        expect(end($events)[1]['code'])->toBe('user_key_invalid')
            ->and($user->aiKey->fresh()->last_error)->not->toBeNull();
    });
});

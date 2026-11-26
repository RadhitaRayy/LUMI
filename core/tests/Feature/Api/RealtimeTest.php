<?php

require_once __DIR__.'/helpers.php';

use App\Enums\AuthCodePurpose;
use App\Events\ConversationCreated;
use App\Events\ConversationDeleted;
use App\Events\ConversationUpdated;
use App\Events\MessageCreated;
use App\Events\SessionRevoked;
use App\Models\User;
use Illuminate\Broadcasting\BroadcastManager;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\PersonalAccessToken;

/** Use a real (Pusher-protocol) broadcaster so channel auth signs responses; nothing is sent over the network. */
function withReverbBroadcaster(): void
{
    config([
        'broadcasting.default' => 'reverb',
        'broadcasting.connections.reverb.key' => 'test-key',
        'broadcasting.connections.reverb.secret' => 'test-secret',
        'broadcasting.connections.reverb.app_id' => '1',
    ]);
    app(BroadcastManager::class)->forgetDrivers();
    require base_path('routes/channels.php');
}

describe('channel authorization', function () {
    it("lets a device join its own user's channel with its token", function () {
        withReverbBroadcaster();
        [$user, $token] = userWithToken();

        $this->withToken($token)
            ->postJson('/api/v1/broadcasting/auth', ['socket_id' => '1234.5678', 'channel_name' => "private-user.{$user->id}"])
            ->assertOk()
            ->assertJsonStructure(['auth']);
    });

    it("refuses another user's channel", function () {
        withReverbBroadcaster();
        [, $token] = userWithToken();
        $other = User::factory()->create(['email' => 'lain@example.com']);

        $this->withToken($token)
            ->postJson('/api/v1/broadcasting/auth', ['socket_id' => '1234.5678', 'channel_name' => "private-user.{$other->id}"])
            ->assertForbidden();
    });

    it('refuses devices without a valid token and blocked accounts', function () {
        withReverbBroadcaster();
        [$user, $token] = userWithToken();
        $body = ['socket_id' => '1234.5678', 'channel_name' => "private-user.{$user->id}"];

        $this->postJson('/api/v1/broadcasting/auth', $body)->assertUnauthorized();

        $user->forceFill(['is_blocked' => true])->save();
        $this->withToken($token)->postJson('/api/v1/broadcasting/auth', $body)
            ->assertForbidden()->assertJsonPath('code', 'account_blocked');
    });
});

describe('conversation events', function () {
    it('broadcasts create, rename and delete to the other devices on the user channel', function () {
        Event::fake([ConversationCreated::class, ConversationUpdated::class, ConversationDeleted::class]);
        [$user, $token] = userWithToken();

        $id = $this->withToken($token)->withHeader('X-Socket-ID', '111.222')
            ->postJson('/api/v1/conversations', ['title' => 'Ide konten'])->json('data.id');

        Event::assertDispatched(ConversationCreated::class, function (ConversationCreated $e) use ($user, $id) {
            return $e->broadcastOn()->name === "private-user.{$user->id}"
                && $e->broadcastAs() === 'conversation.created'
                && $e->broadcastWith()['conversation']['id'] === $id
                && ! array_key_exists('messages', $e->broadcastWith()['conversation'])
                && $e->socket === '111.222'; // the device that made the change is skipped
        });

        $this->withToken($token)->patchJson("/api/v1/conversations/{$id}", ['title' => 'Ide video']);
        Event::assertDispatched(ConversationUpdated::class, fn (ConversationUpdated $e) => $e->broadcastWith()['conversation']['title'] === 'Ide video');

        $this->withToken($token)->deleteJson("/api/v1/conversations/{$id}");
        Event::assertDispatched(ConversationDeleted::class, fn (ConversationDeleted $e) => $e->broadcastWith() === ['id' => $id]);
    });

    it('sends the question right away and the answer when it is finished', function () {
        Event::fake([MessageCreated::class, ConversationUpdated::class]);
        withPlatformModel();
        fakeLlm(['Halo', ' Rayy']);
        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();

        $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'Halo Lumi'])
            ->assertOk()->streamedContent();

        $messages = Event::dispatched(MessageCreated::class)->map(fn ($args) => $args[0]->broadcastWith());
        expect($messages)->toHaveCount(2)
            ->and($messages[0]['conversation_id'])->toBe($conversation->id)
            ->and($messages[0]['message']['role'])->toBe('user')
            ->and($messages[0]['message']['content'])->toBe('Halo Lumi')
            ->and($messages[1]['message']['role'])->toBe('assistant')
            ->and($messages[1]['message']['content'])->toBe('Halo Rayy')
            ->and($messages[1]['message']['status'])->toBe('complete');

        $last = Event::dispatched(ConversationUpdated::class)->last()[0]->broadcastWith();
        expect($last['conversation']['title'])->toBe('Halo Lumi')
            ->and($last['conversation']['last_message_at'])->not->toBeNull();
    });

    it('sends nothing when the chat request is refused before streaming', function () {
        Event::fake([MessageCreated::class, ConversationUpdated::class]);
        fakeLlm();
        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();

        $this->withToken($token)->postJson("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'hai'])
            ->assertStatus(503);

        Event::assertNotDispatched(MessageCreated::class);
    });
});

describe('session events', function () {
    it('returns the token id so a device can recognise its own revocation', function () {
        $user = User::factory()->create(['email' => 'rayy@example.com', 'password' => 'rahasia123']);

        $response = $this->postJson('/api/v1/auth/login', ['email' => 'rayy@example.com', 'password' => 'rahasia123', 'device_name' => 'HP B'])
            ->assertOk();

        $tokenId = $response->json('token_id');
        expect($tokenId)->toBeInt()
            ->and(PersonalAccessToken::findToken($response->json('token'))->id)->toBe($tokenId)
            ->and($user->tokens()->sole()->name)->toBe('HP B');
    });

    it('tells the signed-out device when another device removes it', function () {
        Event::fake([SessionRevoked::class]);
        [$user, $tokenA] = userWithToken(device: 'HP A');
        $tokenB = $user->createToken('HP B')->accessToken;

        $this->withToken($tokenA)->deleteJson("/api/v1/devices/{$tokenB->id}")->assertOk();

        Event::assertDispatched(SessionRevoked::class, fn (SessionRevoked $e) => $e->broadcastAs() === 'session.revoked'
            && $e->broadcastOn()->name === "private-user.{$user->id}"
            && $e->broadcastWith() === ['token_ids' => [$tokenB->id]]);
    });

    it('lists every other device when the password is changed', function () {
        Event::fake([SessionRevoked::class]);
        [$user, $tokenA] = userWithToken(['password' => 'rahasia123'], 'HP A');
        $b = $user->createToken('HP B')->accessToken;
        $c = $user->createToken('Tablet')->accessToken;

        $this->withToken($tokenA)->putJson('/api/v1/me/password', ['current_password' => 'rahasia123', 'password' => 'rahasiaBaru456'])
            ->assertOk();

        Event::assertDispatched(SessionRevoked::class, fn (SessionRevoked $e) => $e->broadcastWith() === ['token_ids' => [$b->id, $c->id]]);
    });

    it('signs out every device after a password reset by email code', function () {
        Event::fake([SessionRevoked::class]);
        Notification::fake();
        $user = User::factory()->create(['email' => 'rayy@example.com']);
        $a = $user->createToken('HP A')->accessToken;
        $b = $user->createToken('HP B')->accessToken;

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'rayy@example.com'])->assertOk();
        $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'rayy@example.com',
            'code' => lastSentCode($user, AuthCodePurpose::ResetPassword),
            'password' => 'rahasiaBaru456',
        ])->assertOk();

        Event::assertDispatched(SessionRevoked::class, fn (SessionRevoked $e) => $e->broadcastWith() === ['token_ids' => [$a->id, $b->id]]);
    });

    it('stays quiet when there were no other devices', function () {
        Event::fake([SessionRevoked::class]);
        [, $token] = userWithToken(['password' => 'rahasia123']);

        $this->withToken($token)->putJson('/api/v1/me/password', ['current_password' => 'rahasia123', 'password' => 'rahasiaBaru456'])
            ->assertOk();

        Event::assertNotDispatched(SessionRevoked::class);
    });
});

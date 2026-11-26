<?php

require_once __DIR__.'/../Api/helpers.php';

use App\Events\SessionRevoked;
use App\Llm\LlmException;
use App\Models\AppSetting;
use App\Models\LlmModel;
use App\Models\LlmProvider;
use App\Models\LlmUsage;
use App\Models\User;
use Illuminate\Support\Facades\Event;
use Inertia\Testing\AssertableInertia as Assert;

function owner(): User
{
    return User::factory()->superadmin()->create(['name' => 'Rayy', 'email' => 'owner@example.com']);
}

describe('access', function () {
    it('sends guests to the sign-in page', function () {
        $this->get('/console')->assertRedirect('/login');
        $this->get('/console/users')->assertRedirect('/login');
    });

    it('lets only the owner sign in', function () {
        User::factory()->create(['email' => 'user@example.com']);
        owner();

        $this->post('/login', ['email' => 'user@example.com', 'password' => 'password'])
            ->assertSessionHasErrors('email');
        $this->assertGuest();

        $this->post('/login', ['email' => 'owner@example.com', 'password' => 'password'])
            ->assertRedirect('/console');
        $this->assertAuthenticated();
    });

    it('refuses a blocked owner at sign-in', function () {
        User::factory()->superadmin()->create(['email' => 'owner@example.com', 'is_blocked' => true]);

        $this->post('/login', ['email' => 'owner@example.com', 'password' => 'password'])
            ->assertSessionHasErrors('email');
        $this->assertGuest();
    });

    it('signs out an app user who somehow has a web session', function () {
        $this->actingAs(User::factory()->create())
            ->get('/console')
            ->assertRedirect('/login')
            ->assertSessionHasErrors('email');

        $this->assertGuest();
    });

    it('has no public sign-up or email reset pages', function () {
        $this->get('/register')->assertNotFound();
        $this->get('/forgot-password')->assertNotFound();
    });
});

describe('dashboard', function () {
    it("shows today's numbers and the default model without its key", function () {
        withPlatformModel();
        $user = User::factory()->create();
        LlmUsage::create(['user_id' => $user->id, 'key_source' => 'platform', 'provider' => 'OpenRouter', 'model' => 'x', 'input_tokens' => 10, 'output_tokens' => 30, 'latency_ms' => 900, 'status' => 'complete']);
        LlmUsage::create(['user_id' => $user->id, 'key_source' => 'platform', 'provider' => 'OpenRouter', 'model' => 'x', 'input_tokens' => 0, 'output_tokens' => 0, 'latency_ms' => 300, 'status' => 'error', 'error_code' => 'provider_rate_limited']);

        $response = $this->actingAs(owner())->get('/console');

        $response->assertInertia(fn (Assert $page) => $page
            ->component('console/dashboard')
            ->where('stats.users', 2)
            ->where('stats.messages', 1)
            ->where('stats.input_tokens', 10)
            ->where('stats.errors', 1)
            ->where('stats.top_error', 'provider_rate_limited')
            ->where('defaultModel.key_last4', '1234')
            ->has('series', 14)
            ->where('series.13.messages', 1)
            ->where('series.13.tokens', 40)
            ->has('recentErrors', 1));

        expect($response->getContent())->not->toContain('sk-or-platform-key');
    });
});

describe('users', function () {
    it('lists, searches and filters users', function () {
        $admin = owner();
        User::factory()->create(['name' => 'Dita', 'email' => 'dita@example.com']);
        User::factory()->create(['name' => 'Sari', 'is_blocked' => true]);

        $this->actingAs($admin)->get('/console/users?q=dit')
            ->assertInertia(fn (Assert $page) => $page
                ->component('console/users')
                ->has('users.data', 1)
                ->where('users.data.0.name', 'Dita')
                ->where('counts.all', 3)
                ->where('counts.blocked', 1));

        $this->actingAs($admin)->get('/console/users?filter=blocked')
            ->assertInertia(fn (Assert $page) => $page->has('users.data', 1)->where('users.data.0.name', 'Sari'));
    });

    it("shows a user's devices and AI key without the key itself", function () {
        $user = User::factory()->create();
        $user->createToken('Galaxy A56');
        $user->aiKey()->create(['driver' => 'openrouter', 'api_key' => 'sk-or-user-secret-9999', 'key_last4' => '9999', 'model_id' => 'x/y:free']);

        $response = $this->actingAs(owner())->get("/console/users?user={$user->id}");

        $response->assertInertia(fn (Assert $page) => $page
            ->where('selected.id', $user->id)
            ->where('selected.own_key', true)
            ->where('selected.ai_key.key_last4', '9999')
            ->where('selected.device_list.0.name', 'Galaxy A56'));
        expect($response->getContent())->not->toContain('sk-or-user-secret');
    });

    it('sets a personal daily quota, or clears it back to the default', function () {
        $user = User::factory()->create();
        $admin = owner();

        $this->actingAs($admin)->patch("/console/users/{$user->id}/quota", ['daily_quota' => 5])->assertRedirect();
        expect($user->fresh()->effectiveDailyQuota())->toBe(5);

        $this->actingAs($admin)->patch("/console/users/{$user->id}/quota", ['daily_quota' => null])->assertRedirect();
        expect($user->fresh()->daily_quota)->toBeNull();
    });

    it('blocking signs the user out of every device and tells those devices', function () {
        Event::fake([SessionRevoked::class]);
        $user = User::factory()->create();
        $a = $user->createToken('HP A')->accessToken;
        $b = $user->createToken('HP B')->accessToken;

        $this->actingAs(owner())->post("/console/users/{$user->id}/block")->assertRedirect();

        expect($user->fresh()->is_blocked)->toBeTrue()->and($user->tokens()->count())->toBe(0);
        Event::assertDispatched(SessionRevoked::class, fn (SessionRevoked $e) => $e->broadcastWith() === ['token_ids' => [$a->id, $b->id]]);

        $this->actingAs(User::firstWhere('email', 'owner@example.com'))->delete("/console/users/{$user->id}/block");
        expect($user->fresh()->is_blocked)->toBeFalse();
    });

    it('never blocks a superadmin', function () {
        $admin = owner();
        $other = User::factory()->superadmin()->create();

        $this->actingAs($admin)->post("/console/users/{$other->id}/block")->assertSessionHasErrors('block');
        expect($other->fresh()->is_blocked)->toBeFalse();
    });

    it('signs out a single device', function () {
        Event::fake([SessionRevoked::class]);
        $user = User::factory()->create();
        $keep = $user->createToken('HP A')->accessToken;
        $drop = $user->createToken('HP B')->accessToken;

        $this->actingAs(owner())->delete("/console/users/{$user->id}/devices/{$drop->id}")->assertRedirect();

        expect($user->tokens()->pluck('id')->all())->toBe([$keep->id]);
        Event::assertDispatched(SessionRevoked::class, fn (SessionRevoked $e) => $e->broadcastWith() === ['token_ids' => [$drop->id]]);

        $other = User::factory()->create();
        $theirs = $other->createToken('HP C')->accessToken;
        $this->actingAs(User::firstWhere('email', 'owner@example.com'))
            ->delete("/console/users/{$user->id}/devices/{$theirs->id}")->assertNotFound();
    });
});

describe('providers and models', function () {
    it('tests a new provider before saving it and makes its model the default', function () {
        $fake = fakeLlm();

        $this->actingAs(owner())->post('/console/providers', [
            'name' => 'NVIDIA NIM',
            'driver' => 'openai_compatible',
            'base_url' => 'https://integrate.api.nvidia.com/v1/',
            'api_key' => 'nvapi-platform-secret-4321',
            'model_id' => 'meta/llama-3.1-8b-instruct',
        ])->assertRedirect()->assertSessionHasNoErrors();

        $provider = LlmProvider::sole();
        expect($provider->base_url)->toBe('https://integrate.api.nvidia.com/v1')
            ->and($provider->api_key)->toBe('nvapi-platform-secret-4321')
            ->and($provider->last_tested_at)->not->toBeNull()
            ->and(LlmModel::platformDefault()?->model_id)->toBe('meta/llama-3.1-8b-instruct')
            ->and($fake->pings[0]->apiKey)->toBe('nvapi-platform-secret-4321');
    });

    it('saves nothing when the provider rejects the key', function () {
        fakeLlm(failPingWith: new LlmException(LlmException::KEY_INVALID, '401'));

        $this->actingAs(owner())->post('/console/providers', [
            'name' => 'OpenRouter',
            'driver' => 'openrouter',
            'api_key' => 'sk-or-wrong-key-0000',
            'model_id' => 'x/y:free',
        ])->assertSessionHasErrors('api_key');

        expect(LlmProvider::count())->toBe(0);
    });

    it('lists providers without ever sending the key to the browser', function () {
        withPlatformModel();

        $response = $this->actingAs(owner())->get('/console/providers');

        $response->assertInertia(fn (Assert $page) => $page
            ->component('console/providers')
            ->where('providers.0.key_last4', '1234')
            ->where('providers.0.models.0.is_default', true)
            ->missing('providers.0.api_key'));
        expect($response->getContent())->not->toContain('sk-or-platform-key');
    });

    it('replaces a key only after it passes the test', function () {
        $model = withPlatformModel();
        $fake = fakeLlm(failPingWith: new LlmException(LlmException::KEY_INVALID, '401'));
        $admin = owner();

        $this->actingAs($admin)->put("/console/providers/{$model->llm_provider_id}/key", ['api_key' => 'sk-or-bad-replacement'])
            ->assertSessionHasErrors('api_key');
        expect($model->provider->fresh()->api_key)->toBe('sk-or-platform-key-1234');

        $fake->failPingWith = null;
        $this->actingAs($admin)->put("/console/providers/{$model->llm_provider_id}/key", ['api_key' => 'sk-or-good-replacement'])
            ->assertSessionHasNoErrors();
        expect($model->provider->fresh()->api_key)->toBe('sk-or-good-replacement');
    });

    it('records the result of a connection test', function () {
        $model = withPlatformModel();
        fakeLlm(failPingWith: new LlmException(LlmException::UNAVAILABLE, '503'));

        $this->actingAs(owner())->post("/console/providers/{$model->llm_provider_id}/test")->assertRedirect();

        expect($model->provider->fresh()->last_error)->not->toBeNull();
    });

    it('adds a model after testing it and switches the default', function () {
        $first = withPlatformModel();
        fakeLlm();
        $admin = owner();

        $this->actingAs($admin)->post("/console/providers/{$first->llm_provider_id}/models", [
            'model_id' => 'nvidia/nemotron-3-ultra-550b-a55b:free',
            'label' => 'Nemotron Ultra',
        ])->assertSessionHasNoErrors();

        $second = LlmModel::firstWhere('model_id', 'nvidia/nemotron-3-ultra-550b-a55b:free');
        $this->actingAs($admin)->post("/console/models/{$second->id}/default")->assertRedirect();

        expect(LlmModel::platformDefault()?->id)->toBe($second->id)
            ->and($first->fresh()->is_default)->toBeFalse();
    });

    it('keeps the default model enabled and undeletable', function () {
        $model = withPlatformModel();
        $admin = owner();

        $this->actingAs($admin)->patch("/console/models/{$model->id}", ['is_enabled' => false])->assertSessionHasErrors('model');
        $this->actingAs($admin)->delete("/console/models/{$model->id}")->assertSessionHasErrors('model');

        expect($model->fresh())->not->toBeNull()->and($model->fresh()->is_enabled)->toBeTrue();
    });
});

describe('settings and logs', function () {
    it('saves the app settings', function () {
        $this->actingAs(owner())->put('/console/settings', [
            'registration_open' => false,
            'require_email_verification' => false,
            'default_daily_quota' => 50,
            'system_prompt' => 'Kamu Lumi.',
        ])->assertRedirect()->assertSessionHasNoErrors();

        $settings = AppSetting::current();
        expect($settings->registration_open)->toBeFalse()
            ->and($settings->default_daily_quota)->toBe(50)
            ->and($settings->system_prompt)->toBe('Kamu Lumi.');
    });

    it('filters the usage log', function () {
        $user = User::factory()->create(['name' => 'Dita']);
        LlmUsage::create(['user_id' => $user->id, 'key_source' => 'user', 'provider' => 'NIM', 'model' => 'a', 'input_tokens' => 1, 'output_tokens' => 1, 'latency_ms' => 100, 'status' => 'complete']);
        LlmUsage::create(['user_id' => $user->id, 'key_source' => 'platform', 'provider' => 'OpenRouter', 'model' => 'b', 'input_tokens' => 0, 'output_tokens' => 0, 'latency_ms' => 100, 'status' => 'error', 'error_code' => 'provider_unavailable']);

        $this->actingAs(owner())->get('/console/logs?status=error')
            ->assertInertia(fn (Assert $page) => $page
                ->component('console/logs')
                ->has('logs.data', 1)
                ->where('logs.data.0.user', 'Dita')
                ->where('logs.data.0.error_code', 'provider_unavailable')
                ->where('filters.status', 'error'));
    });
});

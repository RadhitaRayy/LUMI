<?php

require_once __DIR__.'/helpers.php';

use App\Enums\Role;
use App\Models\AppSetting;
use App\Models\User;
use Illuminate\Support\Facades\Route;

describe('me', function () {
    it('returns the signed-in user with the effective quota', function () {
        AppSetting::current()->update(['default_daily_quota' => 25]);
        [$user, $token] = userWithToken(['name' => 'Rayy']);

        $this->withToken($token)->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('user.name', 'Rayy')
            ->assertJsonPath('user.ai_key_source', 'platform')
            ->assertJsonPath('user.quota.daily_limit', 25)
            ->assertJsonMissingPath('user.password');
    });

    it('uses a per-user quota override when set', function () {
        [, $token] = userWithToken(['daily_quota' => 100]);

        $this->withToken($token)->getJson('/api/v1/me')->assertJsonPath('user.quota.daily_limit', 100);
    });

    it('updates the display name', function () {
        [$user, $token] = userWithToken();

        $this->withToken($token)->patchJson('/api/v1/me', ['name' => 'Radhita'])
            ->assertOk()->assertJsonPath('user.name', 'Radhita');

        expect($user->fresh()->name)->toBe('Radhita');
    });
});

describe('password change', function () {
    it('needs the current password', function () {
        [, $token] = userWithToken(['password' => 'rahasia123']);

        $this->withToken($token)->putJson('/api/v1/me/password', [
            'current_password' => 'bukan-ini', 'password' => 'password-baru-123',
        ])->assertUnprocessable()->assertJsonValidationErrors('current_password');
    });

    it('changes the password and signs out the other devices only', function () {
        [$user, $token] = userWithToken(['password' => 'rahasia123'], 'Galaxy A56');
        $user->createToken('Tablet');

        $this->withToken($token)->putJson('/api/v1/me/password', [
            'current_password' => 'rahasia123', 'password' => 'password-baru-123',
        ])->assertOk();

        expect($user->tokens()->pluck('name')->all())->toBe(['Galaxy A56']);
    });
});

describe('devices', function () {
    it('lists every signed-in device and marks this one', function () {
        [$user, $token] = userWithToken([], 'Galaxy A56');
        $user->createToken('Tablet');

        $response = $this->withToken($token)->getJson('/api/v1/devices')->assertOk();

        $devices = collect($response->json('devices'));
        expect($devices)->toHaveCount(2)
            ->and($devices->firstWhere('name', 'Galaxy A56')['is_current'])->toBeTrue()
            ->and($devices->firstWhere('name', 'Tablet')['is_current'])->toBeFalse();
    });

    it('signs out another device', function () {
        [$user, $token] = userWithToken();
        $tablet = $user->createToken('Tablet')->accessToken;

        $this->withToken($token)->deleteJson("/api/v1/devices/{$tablet->id}")->assertOk();

        expect($user->tokens()->whereKey($tablet->id)->exists())->toBeFalse();
    });

    it("cannot touch someone else's device", function () {
        [, $token] = userWithToken();
        [$other] = userWithToken(['email' => 'lain@example.com'], 'HP orang lain');
        $theirs = $other->tokens()->first();

        $this->withToken($token)->deleteJson("/api/v1/devices/{$theirs->id}")
            ->assertNotFound()->assertJsonPath('code', 'not_found');

        expect($theirs->fresh())->not->toBeNull();
    });
});

describe('email verification gate', function () {
    beforeEach(function () {
        Route::middleware(['api', 'auth:sanctum', 'verified.api'])
            ->get('/api/v1/_gate-check', fn () => ['ok' => true]);
    });

    it('blocks unverified users when verification is required', function () {
        [, $token] = userWithToken(['email_verified_at' => null]);

        $this->withToken($token)->getJson('/api/v1/_gate-check')
            ->assertForbidden()->assertJsonPath('code', 'email_unverified');
    });

    it('lets them through when the Console turns verification off', function () {
        AppSetting::current()->update(['require_email_verification' => false]);
        [, $token] = userWithToken(['email_verified_at' => null]);

        $this->withToken($token)->getJson('/api/v1/_gate-check')->assertOk();
    });
});

describe('lumi:make-superadmin', function () {
    it('creates a verified superadmin account', function () {
        $this->artisan('lumi:make-superadmin', ['email' => 'Owner@Example.com', '--name' => 'Rayy'])
            ->expectsOutputToContain('Superadmin owner@example.com created.')
            ->assertSuccessful();

        $owner = User::where('email', 'owner@example.com')->firstOrFail();
        expect($owner->role)->toBe(Role::Superadmin)
            ->and($owner->hasVerifiedEmail())->toBeTrue();
    });

    it('promotes an existing user', function () {
        $user = User::factory()->create(['email' => 'rayy@example.com']);

        $this->artisan('lumi:make-superadmin', ['email' => 'rayy@example.com'])->assertSuccessful();

        expect($user->fresh()->isSuperadmin())->toBeTrue();
    });

    it('rejects an invalid email', function () {
        $this->artisan('lumi:make-superadmin', ['email' => 'bukan-email'])->assertFailed();
    });
});

<?php

require_once __DIR__.'/helpers.php';

use App\Enums\AuthCodePurpose;
use App\Enums\Role;
use App\Models\AppSetting;
use App\Models\User;
use Illuminate\Support\Facades\Notification;

beforeEach(fn () => Notification::fake());

describe('register', function () {
    it('creates a user, returns a device token and emails a verification code', function () {
        $response = $this->postJson('/api/v1/auth/register', registerPayload());

        $response->assertCreated()
            ->assertJsonPath('user.email', 'rayy@example.com')
            ->assertJsonPath('user.role', 'user')
            ->assertJsonPath('user.email_verified', false)
            ->assertJsonStructure(['user' => ['id', 'name', 'quota'], 'token']);

        $user = User::where('email', 'rayy@example.com')->firstOrFail();
        expect($user->role)->toBe(Role::User)
            ->and($user->tokens()->first()->name)->toBe('Galaxy A56')
            ->and(lastSentCode($user, AuthCodePurpose::VerifyEmail))->toMatch('/^\d{6}$/');
    });

    it('is refused when registration is closed', function () {
        AppSetting::current()->update(['registration_open' => false]);

        $this->postJson('/api/v1/auth/register', registerPayload())
            ->assertForbidden()
            ->assertJsonPath('code', 'registration_closed');
    });

    it('returns validation errors with a stable code', function () {
        User::factory()->create(['email' => 'rayy@example.com']);

        $this->postJson('/api/v1/auth/register', registerPayload(['password' => 'short']))
            ->assertUnprocessable()
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonValidationErrors(['email', 'password']);
    });

    it('never lets a sign-up become superadmin', function () {
        $this->postJson('/api/v1/auth/register', registerPayload(['role' => 'superadmin']))->assertCreated();

        expect(User::where('email', 'rayy@example.com')->first()->role)->toBe(Role::User);
    });
});

describe('login and logout', function () {
    it('returns a token for valid credentials', function () {
        User::factory()->create(['email' => 'rayy@example.com', 'password' => 'rahasia123']);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'Rayy@Example.com',
            'password' => 'rahasia123',
            'device_name' => 'Pixel',
        ])->assertOk()->assertJsonStructure(['user', 'token']);
    });

    it('rejects a wrong password', function () {
        User::factory()->create(['email' => 'rayy@example.com', 'password' => 'rahasia123']);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'rayy@example.com', 'password' => 'salah-banget', 'device_name' => 'Pixel',
        ])->assertUnauthorized()->assertJsonPath('code', 'invalid_credentials');
    });

    it('rejects a blocked account', function () {
        User::factory()->create(['email' => 'rayy@example.com', 'password' => 'rahasia123', 'is_blocked' => true]);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'rayy@example.com', 'password' => 'rahasia123', 'device_name' => 'Pixel',
        ])->assertForbidden()->assertJsonPath('code', 'account_blocked');
    });

    it('stops a blocked user who already has a token', function () {
        [$user, $token] = userWithToken();
        $user->forceFill(['is_blocked' => true])->save();

        $this->withToken($token)->getJson('/api/v1/me')
            ->assertForbidden()->assertJsonPath('code', 'account_blocked');
    });

    it('asks to sign in again without a valid token', function () {
        $this->getJson('/api/v1/me')->assertUnauthorized()->assertJsonPath('code', 'unauthenticated');
    });

    it('revokes only this device on logout', function () {
        [$user, $token] = userWithToken();
        $user->createToken('Tablet');

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();

        expect($user->tokens()->pluck('name')->all())->toBe(['Tablet']);
    });
});

describe('email verification', function () {
    beforeEach(function () {
        $this->postJson('/api/v1/auth/register', registerPayload())->assertCreated();
        $this->user = User::where('email', 'rayy@example.com')->firstOrFail();
        $this->token = $this->user->tokens()->first();
        $this->plain = $this->user->createToken('Galaxy A56')->plainTextToken;
    });

    it('verifies the email with the emailed code', function () {
        $code = lastSentCode($this->user, AuthCodePurpose::VerifyEmail);

        $this->withToken($this->plain)->postJson('/api/v1/auth/email/verify', ['code' => $code])
            ->assertOk()->assertJsonPath('user.email_verified', true);

        expect($this->user->fresh()->hasVerifiedEmail())->toBeTrue();
    });

    it('counts wrong codes and reports attempts left', function () {
        $code = lastSentCode($this->user, AuthCodePurpose::VerifyEmail);
        $wrong = $code === '000000' ? '111111' : '000000';

        $this->withToken($this->plain)->postJson('/api/v1/auth/email/verify', ['code' => $wrong])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'code_invalid')
            ->assertJsonPath('attempts_left', 4);
    });

    it('locks the code after five wrong attempts', function () {
        $code = lastSentCode($this->user, AuthCodePurpose::VerifyEmail);
        $wrong = $code === '000000' ? '111111' : '000000';

        foreach (range(1, 5) as $_) {
            $this->withToken($this->plain)->postJson('/api/v1/auth/email/verify', ['code' => $wrong]);
            $this->travel(61)->seconds(); // stay under the per-minute rate limit
        }

        $this->withToken($this->plain)->postJson('/api/v1/auth/email/verify', ['code' => $code])
            ->assertStatus(429)->assertJsonPath('code', 'code_attempts_exceeded');
    });

    it('refuses an expired code', function () {
        $code = lastSentCode($this->user, AuthCodePurpose::VerifyEmail);
        $this->travel(16)->minutes();

        $this->withToken($this->plain)->postJson('/api/v1/auth/email/verify', ['code' => $code])
            ->assertUnprocessable()->assertJsonPath('code', 'code_expired');
    });

    it('sends a new code on resend and invalidates the old one', function () {
        $old = lastSentCode($this->user, AuthCodePurpose::VerifyEmail);

        $this->withToken($this->plain)->postJson('/api/v1/auth/email/resend')->assertOk();
        $new = lastSentCode($this->user, AuthCodePurpose::VerifyEmail);

        if ($old !== $new) {
            $this->withToken($this->plain)->postJson('/api/v1/auth/email/verify', ['code' => $old])
                ->assertUnprocessable()->assertJsonPath('code', 'code_invalid');
        }

        $this->travel(61)->seconds();
        $this->withToken($this->plain)->postJson('/api/v1/auth/email/verify', ['code' => $new])->assertOk();
    });

    it('limits resend to once a minute', function () {
        $this->withToken($this->plain)->postJson('/api/v1/auth/email/resend')->assertOk();
        $this->withToken($this->plain)->postJson('/api/v1/auth/email/resend')
            ->assertStatus(429)->assertJsonPath('code', 'too_many_requests');
    });
});

describe('password reset', function () {
    it('answers the same for unknown emails and sends nothing', function () {
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'nobody@example.com'])->assertOk();

        Notification::assertNothingSent();
    });

    it('resets the password with the emailed code and signs out every device', function () {
        [$user] = userWithToken(['email' => 'rayy@example.com', 'password' => 'rahasia123']);
        $user->createToken('Tablet');

        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'rayy@example.com'])->assertOk();
        $code = lastSentCode($user, AuthCodePurpose::ResetPassword);

        $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'rayy@example.com', 'code' => $code, 'password' => 'password-baru-123',
        ])->assertOk();

        expect($user->tokens()->count())->toBe(0);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'rayy@example.com', 'password' => 'password-baru-123', 'device_name' => 'Pixel',
        ])->assertOk();
    });

    it('rejects a wrong reset code', function () {
        User::factory()->create(['email' => 'rayy@example.com']);
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'rayy@example.com'])->assertOk();

        $this->postJson('/api/v1/auth/password/reset', [
            'email' => 'rayy@example.com', 'code' => '123456', 'password' => 'password-baru-123',
        ])->assertUnprocessable()->assertJsonPath('code', 'code_invalid');
    });
});

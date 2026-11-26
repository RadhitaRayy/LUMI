<?php

require_once __DIR__.'/helpers.php';

use App\Enums\AuthCodePurpose;
use App\Models\User;
use App\Notifications\AuthCodeNotification;
use Illuminate\Support\Facades\Notification;

beforeEach(fn () => Notification::fake());

it('answers in the language the app asks for', function () {
    $this->withHeader('Accept-Language', 'en')
        ->postJson('/api/v1/auth/login', ['email' => 'nobody@example.com', 'password' => 'salah-sekali', 'device_name' => 'HP'])
        ->assertUnauthorized()
        ->assertJsonPath('code', 'invalid_credentials')
        ->assertJsonPath('message', 'Wrong email or password.');

    $this->withHeader('Accept-Language', 'id-ID,id;q=0.9')
        ->postJson('/api/v1/auth/login', ['email' => 'nobody@example.com', 'password' => 'salah-sekali', 'device_name' => 'HP'])
        ->assertJsonPath('message', 'Email atau password salah.');
});

it('falls back to Indonesian for languages Lumi does not speak yet', function () {
    $this->withHeader('Accept-Language', 'fr-FR')
        ->postJson('/api/v1/auth/login', ['email' => 'nobody@example.com', 'password' => 'salah-sekali', 'device_name' => 'HP'])
        ->assertJsonPath('message', 'Email atau password salah.');
});

it('translates validation messages', function () {
    $this->withHeader('Accept-Language', 'id')
        ->postJson('/api/v1/auth/register', registerPayload(['name' => '']))
        ->assertUnprocessable()
        ->assertJsonPath('errors.name.0', 'Nama wajib diisi.');

    $this->withHeader('Accept-Language', 'en')
        ->postJson('/api/v1/auth/register', registerPayload(['name' => '']))
        ->assertJsonPath('errors.name.0', 'The name field is required.');
});

it('remembers the language picked at sign-up and mails the code in it', function () {
    $this->postJson('/api/v1/auth/register', registerPayload(['locale' => 'en']))
        ->assertCreated()
        ->assertJsonPath('user.locale', 'en');

    $user = User::where('email', registerPayload()['email'])->firstOrFail();

    Notification::assertSentTo($user, AuthCodeNotification::class, function (AuthCodeNotification $n, array $channels, User $notifiable, string $locale) {
        expect($locale)->toBe('en');
        app()->setLocale($locale);
        $mail = $n->toMail($notifiable);

        return $n->purpose === AuthCodePurpose::VerifyEmail
            && $mail->subject === 'Your Lumi email verification code';
    });
});

it('uses the request language when sign-up sends none', function () {
    $this->withHeader('Accept-Language', 'en')
        ->postJson('/api/v1/auth/register', registerPayload())
        ->assertJsonPath('user.locale', 'en');
});

it('rejects languages Lumi does not support', function () {
    $this->postJson('/api/v1/auth/register', registerPayload(['locale' => 'fr']))
        ->assertUnprocessable()
        ->assertJsonValidationErrors('locale');
});

it('changes the language without touching the name', function () {
    [$user, $token] = userWithToken(['name' => 'Rayy']);

    $this->withToken($token)->patchJson('/api/v1/me', ['locale' => 'en'])
        ->assertOk()
        ->assertJsonPath('user.locale', 'en')
        ->assertJsonPath('user.name', 'Rayy');

    expect($user->fresh()->locale)->toBe('en');
});

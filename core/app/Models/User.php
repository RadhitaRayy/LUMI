<?php

namespace App\Models;

use App\Enums\Role;
use Database\Factories\UserFactory;
use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Contracts\Translation\HasLocalePreference;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Carbon;
use Laravel\Fortify\Contracts\PasskeyUser;
use Laravel\Fortify\PasskeyAuthenticatable;
use Laravel\Fortify\TwoFactorAuthenticatable;
use Laravel\Sanctum\HasApiTokens;

/**
 * @property int $id
 * @property string $name
 * @property string $email
 * @property string $locale
 * @property Carbon|null $email_verified_at
 * @property string $password
 * @property string|null $two_factor_secret
 * @property string|null $two_factor_recovery_codes
 * @property Carbon|null $two_factor_confirmed_at
 * @property string|null $remember_token
 * @property Role $role
 * @property bool $is_blocked
 * @property int|null $daily_quota
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 * @property-read UserPersona|null $persona
 */
#[Fillable(['name', 'email', 'password', 'locale'])]
#[Hidden(['password', 'two_factor_secret', 'two_factor_recovery_codes', 'remember_token'])]
class User extends Authenticatable implements HasLocalePreference, MustVerifyEmail, PasskeyUser
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable, PasskeyAuthenticatable, TwoFactorAuthenticatable;

    /** Default attribute values for new users. */
    protected $attributes = [
        'role' => 'user',
        'is_blocked' => false,
        'locale' => 'id',
    ];

    /** Emails (verification and reset codes) go out in the language the user picked in the app. */
    public function preferredLocale(): string
    {
        return $this->locale;
    }

    public function isSuperadmin(): bool
    {
        return $this->role === Role::Superadmin;
    }

    /** Daily message limit when chatting with the platform key. */
    public function effectiveDailyQuota(): int
    {
        return $this->daily_quota ?? AppSetting::current()->default_daily_quota;
    }

    /** Platform-key messages sent today (Asia/Jakarta), counted against the daily quota. */
    public function platformMessagesToday(): int
    {
        $startOfDay = now('Asia/Jakarta')->startOfDay()->utc();

        // Finished turns come from the usage log, which survives deleting the conversation;
        // failed turns (provider errors) are free.
        $finished = LlmUsage::query()
            ->where('user_id', $this->id)
            ->where('key_source', 'platform')
            ->where('status', '!=', 'error')
            ->where('created_at', '>=', $startOfDay)
            ->count();

        // Answers still streaming are not logged yet but must count, or parallel requests could slip past.
        $inFlight = Message::query()
            ->whereIn('conversation_id', $this->conversations()->select('id'))
            ->where('role', Message::ROLE_ASSISTANT)
            ->where('key_source', 'platform')
            ->where('status', 'streaming')
            ->where('created_at', '>=', $startOfDay)
            ->count();

        return $finished + $inFlight;
    }

    /** The user's own AI key if it is set and switched on. */
    public function activeAiKey(): ?UserAiKey
    {
        return $this->aiKey()->where('is_active', true)->first();
    }

    /** @return HasMany<AuthCode, $this> */
    public function authCodes(): HasMany
    {
        return $this->hasMany(AuthCode::class);
    }

    /** @return HasMany<Conversation, $this> */
    public function conversations(): HasMany
    {
        return $this->hasMany(Conversation::class);
    }

    /** @return HasOne<UserAiKey, $this> */
    public function aiKey(): HasOne
    {
        return $this->hasOne(UserAiKey::class);
    }

    /** @return HasOne<UserPersona, $this> */
    public function persona(): HasOne
    {
        return $this->hasOne(UserPersona::class);
    }

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'two_factor_confirmed_at' => 'datetime',
            'role' => Role::class,
            'is_blocked' => 'boolean',
            'daily_quota' => 'integer',
        ];
    }
}

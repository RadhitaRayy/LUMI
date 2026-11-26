<?php

namespace App\Models;

use App\Enums\AuthCodePurpose;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * One-time 6-digit code sent by email (email verification, password reset).
 *
 * @property int $id
 * @property int $user_id
 * @property AuthCodePurpose $purpose
 * @property string $code_hash
 * @property Carbon $expires_at
 * @property int $attempts
 * @property Carbon|null $used_at
 */
#[Fillable(['user_id', 'purpose', 'code_hash', 'expires_at', 'attempts', 'used_at'])]
#[Hidden(['code_hash'])]
class AuthCode extends Model
{
    protected function casts(): array
    {
        return [
            'purpose' => AuthCodePurpose::class,
            'expires_at' => 'datetime',
            'used_at' => 'datetime',
            'attempts' => 'integer',
        ];
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

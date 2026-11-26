<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A user's own AI key (hybrid BYOK). The key itself never leaves the server.
 *
 * @property int $id
 * @property int $user_id
 * @property string $driver
 * @property string|null $base_url
 * @property string $api_key
 * @property string $key_last4
 * @property string $model_id
 * @property bool $is_active
 * @property Carbon|null $last_validated_at
 * @property string|null $last_error
 */
#[Fillable(['driver', 'base_url', 'api_key', 'key_last4', 'model_id', 'is_active', 'last_validated_at', 'last_error'])]
#[Hidden(['api_key'])]
class UserAiKey extends Model
{
    protected function casts(): array
    {
        return [
            'api_key' => 'encrypted',
            'is_active' => 'boolean',
            'last_validated_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

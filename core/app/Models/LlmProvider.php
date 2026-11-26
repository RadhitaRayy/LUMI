<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * A platform AI provider configured by the superadmin (platform key).
 *
 * @property int $id
 * @property string $name
 * @property string $driver
 * @property string|null $base_url
 * @property string|null $api_key
 * @property bool $is_enabled
 * @property Carbon|null $last_tested_at
 * @property string|null $last_error
 */
#[Fillable(['name', 'driver', 'base_url', 'api_key', 'is_enabled', 'last_tested_at', 'last_error'])]
#[Hidden(['api_key'])]
class LlmProvider extends Model
{
    protected function casts(): array
    {
        return [
            'api_key' => 'encrypted',
            'is_enabled' => 'boolean',
            'last_tested_at' => 'datetime',
        ];
    }

    /** Last four characters of the key, for display. The key itself never leaves the server. */
    public function keyLast4(): ?string
    {
        return $this->api_key ? substr($this->api_key, -4) : null;
    }

    /** @return HasMany<LlmModel, $this> */
    public function models(): HasMany
    {
        return $this->hasMany(LlmModel::class);
    }
}

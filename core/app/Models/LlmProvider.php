<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A platform AI provider configured by the superadmin (platform key).
 *
 * @property int $id
 * @property string $name
 * @property string $driver
 * @property string|null $base_url
 * @property string|null $api_key
 * @property bool $is_enabled
 */
#[Fillable(['name', 'driver', 'base_url', 'api_key', 'is_enabled'])]
#[Hidden(['api_key'])]
class LlmProvider extends Model
{
    protected function casts(): array
    {
        return [
            'api_key' => 'encrypted',
            'is_enabled' => 'boolean',
        ];
    }

    /** @return HasMany<LlmModel, $this> */
    public function models(): HasMany
    {
        return $this->hasMany(LlmModel::class);
    }
}

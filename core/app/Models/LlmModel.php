<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property int $id
 * @property int $llm_provider_id
 * @property string $model_id
 * @property string $label
 * @property bool $is_default
 * @property bool $supports_tools
 * @property bool $is_enabled
 * @property-read LlmProvider $provider
 */
#[Fillable(['llm_provider_id', 'model_id', 'label', 'is_default', 'supports_tools', 'is_enabled'])]
class LlmModel extends Model
{
    protected function casts(): array
    {
        return [
            'is_default' => 'boolean',
            'supports_tools' => 'boolean',
            'is_enabled' => 'boolean',
        ];
    }

    /** @return BelongsTo<LlmProvider, $this> */
    public function provider(): BelongsTo
    {
        return $this->belongsTo(LlmProvider::class, 'llm_provider_id');
    }

    /** The enabled default model whose provider is enabled, if any. */
    public static function platformDefault(): ?self
    {
        return static::query()
            ->with('provider')
            ->where('is_enabled', true)
            ->whereHas('provider', fn ($q) => $q->where('is_enabled', true))
            ->orderByDesc('is_default')
            ->oldest('id')
            ->first();
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Per-user persona configuration (Layer 4 of the system prompt).
 *
 * @property int $id
 * @property int $user_id
 * @property string $preset
 * @property string|null $call_me
 * @property string|null $custom_instructions
 * @property bool $is_active
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
#[Fillable(['user_id', 'preset', 'call_me', 'custom_instructions', 'is_active'])]
class UserPersona extends Model
{
    public const PRESET_SANTAI = 'santai';

    public const PRESET_PROFESIONAL = 'profesional';

    public const PRESET_CODING = 'coding';

    public const PRESET_RINGKAS = 'ringkas';

    public const PRESET_CUSTOM = 'custom';

    /** @var list<string> */
    public const PRESETS = [
        self::PRESET_SANTAI,
        self::PRESET_PROFESIONAL,
        self::PRESET_CODING,
        self::PRESET_RINGKAS,
        self::PRESET_CUSTOM,
    ];

    public const MAX_CALL_ME_LENGTH = 40;

    public const MAX_CUSTOM_INSTRUCTIONS_LENGTH = 1000;

    protected $attributes = [
        'preset' => self::PRESET_SANTAI,
        'is_active' => true,
    ];

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return array<string, mixed> */
    public function toApiArray(): array
    {
        return [
            'preset' => $this->preset,
            'call_me' => $this->call_me,
            'custom_instructions' => $this->custom_instructions,
            'is_active' => $this->is_active,
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }

    /**
     * Default unsaved persona payload for users who haven't customized one yet.
     *
     * @return array<string, mixed>
     */
    public static function defaultApiArray(): array
    {
        return [
            'preset' => self::PRESET_SANTAI,
            'call_me' => null,
            'custom_instructions' => null,
            'is_active' => true,
            'updated_at' => null,
        ];
    }

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }
}

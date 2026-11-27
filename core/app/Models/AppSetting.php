<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

/**
 * Platform settings managed from Lumi Console. Always a single row.
 *
 * @property bool $registration_open
 * @property bool $require_email_verification
 * @property int $default_daily_quota
 * @property string|null $system_prompt
 * @property string|null $web_search_driver
 * @property string|null $web_search_api_key
 * @property bool $web_search_enabled
 */
#[Fillable([
    'registration_open',
    'require_email_verification',
    'default_daily_quota',
    'system_prompt',
    'web_search_driver',
    'web_search_api_key',
    'web_search_enabled',
])]
class AppSetting extends Model
{
    protected function casts(): array
    {
        return [
            'registration_open' => 'boolean',
            'require_email_verification' => 'boolean',
            'default_daily_quota' => 'integer',
            'web_search_api_key' => 'encrypted',
            'web_search_enabled' => 'boolean',
        ];
    }

    /** The settings row, created with defaults if it is missing. */
    public static function current(): self
    {
        return static::query()->oldest('id')->first()
            ?? static::query()->create([
                'registration_open' => true,
                'require_email_verification' => true,
                'default_daily_quota' => 30,
            ])->refresh();
    }
}

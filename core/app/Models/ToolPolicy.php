<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * Per-role permission override for an agent tool (managed in Lumi Console).
 *
 * @property int $id
 * @property string $tool_name
 * @property string $role
 * @property string $mode
 * @property bool $is_enabled
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
#[Fillable(['tool_name', 'role', 'mode', 'is_enabled'])]
class ToolPolicy extends Model
{
    public const MODE_AUTO = 'auto';

    public const MODE_ASK = 'ask';

    public const MODE_DISABLED = 'disabled';

    /** @var list<string> */
    public const MODES = [
        self::MODE_AUTO,
        self::MODE_ASK,
        self::MODE_DISABLED,
    ];

    protected function casts(): array
    {
        return [
            'is_enabled' => 'boolean',
        ];
    }
}

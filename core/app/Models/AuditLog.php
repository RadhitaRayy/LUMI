<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Immutable audit trail for every agent tool execution, denial, or approval decision.
 *
 * @property string $id
 * @property int $user_id
 * @property string|null $conversation_id
 * @property string $tool_name
 * @property string $mode
 * @property string $status
 * @property string|null $summary
 * @property int|null $latency_ms
 * @property Carbon|null $created_at
 */
#[Fillable([
    'user_id',
    'conversation_id',
    'tool_name',
    'mode',
    'status',
    'summary',
    'latency_ms',
    'created_at',
])]
class AuditLog extends Model
{
    use HasUlids;

    public $timestamps = false;

    public const STATUS_EXECUTED = 'executed';

    public const STATUS_APPROVED = 'approved';

    public const STATUS_REJECTED = 'rejected';

    public const STATUS_EXPIRED = 'expired';

    public const STATUS_DENIED = 'denied';

    public const STATUS_ERROR = 'error';

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'latency_ms' => 'integer',
            'created_at' => 'datetime',
        ];
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * An `ask`-mode tool call paused waiting for the user's explicit Approve or Reject decision.
 *
 * @property string $id
 * @property int $user_id
 * @property string $conversation_id
 * @property string $message_id
 * @property string $tool_call_id
 * @property string $tool_name
 * @property array<string, mixed> $arguments
 * @property string $title
 * @property string $summary
 * @property array<string, mixed> $continuation
 * @property string $status
 * @property Carbon $expires_at
 * @property Carbon|null $resolved_at
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
#[Fillable([
    'user_id',
    'conversation_id',
    'message_id',
    'tool_call_id',
    'tool_name',
    'arguments',
    'title',
    'summary',
    'continuation',
    'status',
    'expires_at',
    'resolved_at',
])]
class PendingAction extends Model
{
    use HasUlids;

    public const STATUS_PENDING = 'pending';

    public const STATUS_APPROVED = 'approved';

    public const STATUS_REJECTED = 'rejected';

    public const STATUS_EXPIRED = 'expired';

    public const TTL_MINUTES = 10;

    /** Marks any overdue pending actions for [$userId] (or all users) as expired and logs to audit_logs. */
    public static function expireOverdue(?int $userId = null): int
    {
        $overdue = static::query()
            ->where('status', self::STATUS_PENDING)
            ->where('expires_at', '<=', now())
            ->when($userId !== null, fn ($q) => $q->where('user_id', $userId))
            ->get();

        foreach ($overdue as $action) {
            $action->forceFill([
                'status' => self::STATUS_EXPIRED,
                'resolved_at' => now(),
            ])->save();

            Message::query()
                ->whereKey($action->message_id)
                ->where('status', 'awaiting_approval')
                ->update(['status' => 'cancelled']);

            AuditLog::create([
                'user_id' => $action->user_id,
                'conversation_id' => $action->conversation_id,
                'tool_name' => $action->tool_name,
                'mode' => ToolPolicy::MODE_ASK,
                'status' => AuditLog::STATUS_EXPIRED,
                'summary' => $action->summary,
                'created_at' => now(),
            ]);
        }

        return $overdue->count();
    }

    public function isExpired(): bool
    {
        return $this->status === self::STATUS_EXPIRED || $this->expires_at->isPast();
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return BelongsTo<Conversation, $this> */
    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class);
    }

    /** @return BelongsTo<Message, $this> */
    public function message(): BelongsTo
    {
        return $this->belongsTo(Message::class);
    }

    /** @return array<string, mixed> */
    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'conversation_id' => $this->conversation_id,
            'message_id' => $this->message_id,
            'tool' => $this->tool_name,
            'title' => $this->title,
            'summary' => $this->summary,
            'status' => $this->status,
            'expires_at' => $this->expires_at->toIso8601String(),
            'resolved_at' => $this->resolved_at?->toIso8601String(),
        ];
    }

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'arguments' => 'array',
            'continuation' => 'encrypted:array',
            'expires_at' => 'datetime',
            'resolved_at' => 'datetime',
        ];
    }
}

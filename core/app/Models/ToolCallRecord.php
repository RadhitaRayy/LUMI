<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * One tool execution performed by the agent during an assistant message.
 *
 * @property string $id
 * @property string $conversation_id
 * @property string $message_id
 * @property int $user_id
 * @property string $tool_name
 * @property array<string, mixed> $arguments
 * @property string|null $result_summary
 * @property string $status
 * @property int $latency_ms
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
#[Fillable([
    'conversation_id',
    'message_id',
    'user_id',
    'tool_name',
    'arguments',
    'result_summary',
    'status',
    'latency_ms',
])]
class ToolCallRecord extends Model
{
    use HasUlids;

    protected $table = 'tool_calls';

    public const STATUS_OK = 'ok';

    public const STATUS_ERROR = 'error';

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
            'tool' => $this->tool_name,
            'status' => $this->status,
            'summary' => $this->result_summary ?? '',
            'latency_ms' => $this->latency_ms,
        ];
    }

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'arguments' => 'array',
            'latency_ms' => 'integer',
        ];
    }
}

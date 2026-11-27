<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * @property string $id
 * @property string $conversation_id
 * @property string $role
 * @property string $content
 * @property string $status
 * @property string|null $key_source
 * @property string|null $provider
 * @property string|null $model
 * @property int|null $input_tokens
 * @property int|null $output_tokens
 * @property string|null $error_code
 * @property Carbon|null $created_at
 */
#[Fillable(['role', 'content', 'status', 'key_source', 'provider', 'model', 'input_tokens', 'output_tokens', 'error_code'])]
class Message extends Model
{
    use HasUlids;

    public const ROLE_USER = 'user';

    public const ROLE_ASSISTANT = 'assistant';

    /** An answer still `streaming` after this long was cut off (the PHP process died mid-answer). */
    public const STALE_AFTER_MINUTES = 5;

    /**
     * Marks answers that never finished as failed, so apps stop waiting for them and they no
     * longer count toward the daily quota. Returns how many were marked.
     */
    public static function expireStale(?int $userId = null): int
    {
        return static::query()
            ->where('status', 'streaming')
            ->where('updated_at', '<', now()->subMinutes(self::STALE_AFTER_MINUTES))
            ->when($userId !== null, fn ($q) => $q->whereHas('conversation', fn ($c) => $c->where('user_id', $userId)))
            ->update(['status' => 'error', 'error_code' => 'interrupted', 'updated_at' => now()]);
    }

    protected function casts(): array
    {
        return [
            'input_tokens' => 'integer',
            'output_tokens' => 'integer',
        ];
    }

    /** @return BelongsTo<Conversation, $this> */
    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class);
    }
}

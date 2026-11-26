<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * @property int $id
 * @property int $user_id
 * @property string|null $conversation_id
 * @property string $key_source
 * @property string $provider
 * @property string $model
 * @property int $input_tokens
 * @property int $output_tokens
 * @property int $latency_ms
 * @property string $status
 * @property string|null $error_code
 */
#[Fillable(['user_id', 'conversation_id', 'message_id', 'key_source', 'provider', 'model', 'input_tokens', 'output_tokens', 'latency_ms', 'status', 'error_code'])]
class LlmUsage extends Model
{
    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

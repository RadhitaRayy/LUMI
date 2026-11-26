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

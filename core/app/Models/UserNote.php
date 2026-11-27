<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * Personal note saved manually by the user or by Lumi's notes tool.
 *
 * @property string $id
 * @property int $user_id
 * @property string $title
 * @property string $content
 * @property list<string> $tags
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
#[Fillable(['user_id', 'title', 'content', 'tags'])]
class UserNote extends Model
{
    use HasUlids;

    public const MAX_TITLE_LENGTH = 120;

    public const MAX_CONTENT_LENGTH = 10000;

    public const MAX_TAGS = 10;

    public const MAX_TAG_LENGTH = 30;

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return array<string, mixed> */
    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'content' => $this->content,
            'tags' => $this->tags,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }

    /** @return array<string, string> */
    protected function casts(): array
    {
        return [
            'tags' => 'array',
        ];
    }
}

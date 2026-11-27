<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * One lasting fact or preference remembered about a user across conversations.
 *
 * @property string $id
 * @property int $user_id
 * @property string $category
 * @property string $content
 * @property string $source
 * @property Carbon|null $created_at
 * @property Carbon|null $updated_at
 */
#[Fillable(['user_id', 'category', 'content', 'source'])]
class UserMemory extends Model
{
    use HasUlids;

    public const CATEGORY_PREFERENCE = 'preference';

    public const CATEGORY_FACT = 'fact';

    public const CATEGORY_CONTEXT = 'context';

    /** @var list<string> */
    public const CATEGORIES = [
        self::CATEGORY_PREFERENCE,
        self::CATEGORY_FACT,
        self::CATEGORY_CONTEXT,
    ];

    public const SOURCE_AGENT = 'agent';

    public const SOURCE_USER = 'user';

    public const MAX_PER_USER = 50;

    public const CONTEXT_LIMIT = 20;

    public const MAX_CONTENT_LENGTH = 300;

    protected $attributes = [
        'category' => self::CATEGORY_FACT,
        'source' => self::SOURCE_USER,
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
            'id' => $this->id,
            'category' => $this->category,
            'content' => $this->content,
            'source' => $this->source,
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}

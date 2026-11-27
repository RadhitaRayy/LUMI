<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\NoteChanged;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserNote;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NoteController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $q = trim((string) $request->query('q', ''));

        $query = $user->notes()->latest('updated_at')->latest('id');
        if ($q !== '') {
            $pattern = '%'.$this->escapeLike($q).'%';
            $query->where(function ($sub) use ($pattern) {
                $sub->whereLike('title', $pattern)
                    ->orWhereLike('content', $pattern)
                    ->orWhereRaw('tags::text ILIKE ?', [$pattern]);
            });
        }

        $page = $query->paginate(20);

        return response()->json([
            'data' => collect($page->items())->map(fn (UserNote $n) => $n->toApiArray())->values()->all(),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $data = $request->validate([
            'title' => ['required', 'string', 'max:'.UserNote::MAX_TITLE_LENGTH],
            'content' => ['required', 'string', 'max:'.UserNote::MAX_CONTENT_LENGTH],
            'tags' => ['sometimes', 'array', 'max:'.UserNote::MAX_TAGS],
            'tags.*' => ['nullable', 'string', 'max:'.UserNote::MAX_TAG_LENGTH],
        ]);

        /** @var UserNote $note */
        $note = $user->notes()->create([
            'title' => trim($data['title']),
            'content' => trim($data['content']),
            'tags' => $this->normalizeTags($data['tags'] ?? []),
        ]);

        broadcast(NoteChanged::created($note))->toOthers();

        return response()->json(['data' => $note->toApiArray()], 201);
    }

    public function update(Request $request, string $note): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        /** @var UserNote $record */
        $record = $user->notes()->whereKey($note)->firstOrFail();

        $data = $request->validate([
            'title' => ['sometimes', 'required', 'string', 'max:'.UserNote::MAX_TITLE_LENGTH],
            'content' => ['sometimes', 'required', 'string', 'max:'.UserNote::MAX_CONTENT_LENGTH],
            'tags' => ['sometimes', 'array', 'max:'.UserNote::MAX_TAGS],
            'tags.*' => ['nullable', 'string', 'max:'.UserNote::MAX_TAG_LENGTH],
        ]);

        if (isset($data['title'])) {
            $record->title = trim($data['title']);
        }
        if (isset($data['content'])) {
            $record->content = trim($data['content']);
        }
        if (array_key_exists('tags', $data)) {
            $record->tags = $this->normalizeTags($data['tags']);
        }
        $record->save();

        broadcast(NoteChanged::updated($record))->toOthers();

        return response()->json(['data' => $record->toApiArray()]);
    }

    public function destroy(Request $request, string $note): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        /** @var UserNote $record */
        $record = $user->notes()->whereKey($note)->firstOrFail();

        $id = $record->id;
        $record->delete();

        broadcast(NoteChanged::deleted($user->id, $id))->toOthers();

        return response()->json(['message' => __('Note deleted.')]);
    }

    /**
     * @param  array<int, mixed>  $tags
     * @return list<string>
     */
    private function normalizeTags(array $tags): array
    {
        $clean = [];
        foreach ($tags as $tag) {
            if (! is_string($tag)) {
                continue;
            }
            $value = trim($tag);
            if ($value !== '' && ! in_array($value, $clean, true)) {
                $clean[] = $value;
            }
        }

        return $clean;
    }

    private function escapeLike(string $value): string
    {
        return str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $value);
    }
}

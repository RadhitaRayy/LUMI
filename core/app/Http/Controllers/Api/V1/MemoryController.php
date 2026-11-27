<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\MemoryChanged;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserMemory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class MemoryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $q = trim((string) $request->query('q', ''));

        $query = $user->memories()->latest('updated_at')->latest('id');
        if ($q !== '') {
            $query->whereLike('content', '%'.$this->escapeLike($q).'%');
        }

        $items = $query->get();

        return response()->json([
            'data' => $items->map(fn (UserMemory $m) => $m->toApiArray())->values()->all(),
            'count' => $user->memories()->count(),
            'limit' => UserMemory::MAX_PER_USER,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $data = $request->validate([
            'content' => ['required', 'string', 'max:'.UserMemory::MAX_CONTENT_LENGTH],
            'category' => ['sometimes', 'string', Rule::in(UserMemory::CATEGORIES)],
        ]);

        if ($user->memories()->count() >= UserMemory::MAX_PER_USER) {
            throw new ApiException(
                'memory_limit_reached',
                __('Memory limit reached (:limit items). Delete an older memory first.', ['limit' => UserMemory::MAX_PER_USER]),
                422,
            );
        }

        /** @var UserMemory $memory */
        $memory = $user->memories()->create([
            'content' => trim($data['content']),
            'category' => $data['category'] ?? UserMemory::CATEGORY_FACT,
            'source' => UserMemory::SOURCE_USER,
        ]);

        broadcast(MemoryChanged::created($memory))->toOthers();

        return response()->json(['data' => $memory->toApiArray()], 201);
    }

    public function update(Request $request, string $memory): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        /** @var UserMemory $record */
        $record = $user->memories()->whereKey($memory)->firstOrFail();

        $data = $request->validate([
            'content' => ['sometimes', 'required', 'string', 'max:'.UserMemory::MAX_CONTENT_LENGTH],
            'category' => ['sometimes', 'string', Rule::in(UserMemory::CATEGORIES)],
        ]);

        if (isset($data['content'])) {
            $record->content = trim($data['content']);
        }
        if (isset($data['category'])) {
            $record->category = $data['category'];
        }
        $record->save();

        broadcast(MemoryChanged::updated($record))->toOthers();

        return response()->json(['data' => $record->toApiArray()]);
    }

    public function destroy(Request $request, string $memory): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        /** @var UserMemory $record */
        $record = $user->memories()->whereKey($memory)->firstOrFail();

        $id = $record->id;
        $record->delete();

        broadcast(MemoryChanged::deleted($user->id, $id))->toOthers();

        return response()->json(['message' => __('Memory deleted.')]);
    }

    private function escapeLike(string $value): string
    {
        return str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $value);
    }
}

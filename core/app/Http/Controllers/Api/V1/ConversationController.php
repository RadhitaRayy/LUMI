<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ConversationResource;
use App\Models\Conversation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ConversationController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $q = trim((string) $request->query('q', ''));

        $conversations = $request->user()->conversations()
            ->when($q !== '', function ($query) use ($q) {
                $like = '%'.str_replace(['%', '_'], ['\%', '\_'], $q).'%';
                $query->where(fn ($w) => $w
                    ->where('title', 'ilike', $like)
                    ->orWhereHas('messages', fn ($m) => $m->where('content', 'ilike', $like)));
            })
            ->orderByDesc('last_message_at')
            ->orderByDesc('created_at')
            ->paginate(20);

        return ConversationResource::collection($conversations);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['nullable', 'string', 'max:120'],
        ]);

        $conversation = $request->user()->conversations()->create([
            'title' => $data['title'] ?? null,
        ]);

        return (new ConversationResource($conversation))->response()->setStatusCode(201);
    }

    public function show(Request $request, Conversation $conversation): ConversationResource
    {
        $this->ensureOwner($request, $conversation);

        return new ConversationResource($conversation->load('messages'));
    }

    public function update(Request $request, Conversation $conversation): ConversationResource
    {
        $this->ensureOwner($request, $conversation);

        $data = $request->validate([
            'title' => ['required', 'string', 'max:120'],
        ]);

        $conversation->update($data);

        return new ConversationResource($conversation);
    }

    public function destroy(Request $request, Conversation $conversation): JsonResponse
    {
        $this->ensureOwner($request, $conversation);

        $conversation->delete();

        return response()->json(['message' => 'Percakapan dihapus.']);
    }

    /** Someone else's conversation looks exactly like a missing one. */
    private function ensureOwner(Request $request, Conversation $conversation): void
    {
        abort_unless($conversation->user_id === $request->user()->id, 404);
    }
}

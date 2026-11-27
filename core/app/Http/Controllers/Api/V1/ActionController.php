<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PendingAction;
use App\Models\User;
use App\Services\Chat\ChatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ActionController extends Controller
{
    public function __construct(
        private readonly ChatService $chat,
    ) {}

    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        PendingAction::expireOverdue($user->id);

        $actions = PendingAction::query()
            ->where('user_id', $user->id)
            ->where('status', PendingAction::STATUS_PENDING)
            ->latest('created_at')
            ->get();

        return response()->json([
            'data' => $actions->map(fn (PendingAction $a) => $a->toApiArray())->values()->all(),
        ]);
    }

    public function approve(Request $request, string $action): StreamedResponse
    {
        return $this->resolve($request, $action, approved: true);
    }

    public function reject(Request $request, string $action): StreamedResponse
    {
        return $this->resolve($request, $action, approved: false);
    }

    private function resolve(Request $request, string $actionId, bool $approved): StreamedResponse
    {
        /** @var User $user */
        $user = $request->user();

        /** @var PendingAction $record */
        $record = PendingAction::query()
            ->where('user_id', $user->id)
            ->whereKey($actionId)
            ->firstOrFail();

        $resolved = $this->chat->prepareResume($user, $record, $approved);

        return response()->stream(function () use ($user, $resolved, $approved): void {
            @set_time_limit(180);

            $emit = static function (string $event, array $data): void {
                echo "event: {$event}\n";
                echo 'data: '.json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)."\n\n";
                if (ob_get_level() > 0) {
                    @ob_flush();
                }
                flush();
            };

            $this->chat->streamResume($user, $resolved, $approved, $emit, static fn (): bool => connection_aborted() !== 0);
        }, 200, [
            'Content-Type' => 'text/event-stream; charset=UTF-8',
            'Cache-Control' => 'no-cache, no-transform',
            'Connection' => 'keep-alive',
            'X-Accel-Buffering' => 'no',
        ]);
    }
}

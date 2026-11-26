<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Conversation;
use App\Services\Chat\ChatService;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class MessageController extends Controller
{
    /**
     * Send a message and stream the answer as Server-Sent Events.
     *
     * Events: message.start, delta, message.end, error.
     */
    public function store(Request $request, Conversation $conversation, ChatService $chat): StreamedResponse
    {
        abort_unless($conversation->user_id === $request->user()->id, 404);

        $data = $request->validate([
            'content' => ['required', 'string', 'max:8000'],
        ]);

        // Quota, model and message rows are settled before streaming, so failures are plain JSON.
        $turn = $chat->prepare($request->user(), $conversation, trim($data['content']));

        return response()->stream(function () use ($chat, $turn) {
            ignore_user_abort(true); // always finish saving the answer

            $chat->stream(
                $turn,
                function (string $event, array $data) {
                    echo "event: {$event}\n";
                    echo 'data: '.json_encode($data, JSON_UNESCAPED_UNICODE)."\n\n";
                    if (ob_get_level() > 0) {
                        ob_flush();
                    }
                    flush();
                },
                fn () => connection_aborted() === 1,
            );
        }, 200, [
            'Content-Type' => 'text/event-stream',
            'Cache-Control' => 'no-cache, no-transform',
            'X-Accel-Buffering' => 'no',
        ]);
    }
}

<?php

require_once __DIR__.'/helpers.php';

use App\Events\ActionPending;
use App\Events\ActionResolved;
use App\Llm\LlmToolCall;
use App\Models\AuditLog;
use App\Models\Message;
use App\Models\PendingAction;
use App\Models\UserNote;
use Illuminate\Support\Facades\Event;

describe('action approval (ask mode)', function () {
    it('pauses non-blockingly on ask tool, resumes on approve, executes tool and logs audit', function () {
        Event::fake([ActionPending::class, ActionResolved::class]);
        withPlatformModel();
        $fake = fakeLlm();
        [$user, $token] = userWithToken();
        $note = $user->notes()->create(['title' => 'Draft Lama', 'content' => 'Isi lama', 'tags' => []]);

        $fake->steps = [
            ['tool_calls' => [new LlmToolCall('call-del', 'delete_note', ['note_id' => $note->id])]],
            ['chunks' => ['Catatan Draft Lama ', 'sudah dihapus.']],
        ];

        $conversation = $user->conversations()->create();
        $pauseEvents = sseEvents(
            $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", [
                'content' => 'Hapus catatan Draft Lama',
            ])->assertOk()->streamedContent()
        );

        expect(array_column($pauseEvents, 0))->toBe(['message.start', 'action.pending'])
            ->and(UserNote::find($note->id))->not->toBeNull();

        $actionId = $pauseEvents[1][1]['id'];
        expect($pauseEvents[1][1]['summary'])->toContain('Draft Lama');
        Event::assertDispatched(ActionPending::class, fn (ActionPending $e) => $e->userId === $user->id);

        // Listed in /actions/pending and visible on conversation reload.
        $this->withToken($token)->getJson('/api/v1/actions/pending')
            ->assertOk()
            ->assertJsonPath('data.0.id', $actionId);

        $conv = $this->withToken($token)->getJson("/api/v1/conversations/{$conversation->id}")->assertOk()->json('data');
        expect($conv['messages'][1]['status'])->toBe('awaiting_approval')
            ->and($conv['messages'][1]['pending_action']['id'])->toBe($actionId);

        // Approve resumes via SSE and executes delete_note.
        $resumeEvents = sseEvents(
            $this->withToken($token)->post("/api/v1/actions/{$actionId}/approve")
                ->assertOk()->streamedContent()
        );

        expect(array_column($resumeEvents, 0))->toBe(['message.start', 'tool.start', 'tool.end', 'delta', 'delta', 'message.end'])
            ->and(UserNote::find($note->id))->toBeNull()
            ->and(PendingAction::find($actionId)->status)->toBe(PendingAction::STATUS_APPROVED)
            ->and(AuditLog::where('tool_name', 'delete_note')->where('status', AuditLog::STATUS_APPROVED)->count())->toBe(1);

        Event::assertDispatched(ActionResolved::class, fn (ActionResolved $e) => $e->payload['status'] === 'approved');

        $assistant = Message::find($pauseEvents[0][1]['message_id']);
        expect($assistant->status)->toBe('complete')
            ->and($assistant->content)->toBe('Catatan Draft Lama sudah dihapus.');

        // Second approve returns 409 action_already_resolved.
        $this->withToken($token)->postJson("/api/v1/actions/{$actionId}/approve")
            ->assertStatus(409)
            ->assertJsonPath('code', 'action_already_resolved');
    });

    it('rejects without executing tool, logs rejected audit, and responds gracefully', function () {
        Event::fake([ActionPending::class, ActionResolved::class]);
        withPlatformModel();
        $fake = fakeLlm();
        [$user, $token] = userWithToken();
        $note = $user->notes()->create(['title' => 'Rahasia', 'content' => 'Aman', 'tags' => []]);

        $fake->steps = [
            ['tool_calls' => [new LlmToolCall('call-del', 'delete_note', ['note_id' => $note->id])]],
            ['chunks' => ['Baik, catatan tidak jadi dihapus.']],
        ];

        $conversation = $user->conversations()->create();
        $pauseEvents = sseEvents(
            $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", [
                'content' => 'Hapus catatan Rahasia',
            ])->assertOk()->streamedContent()
        );
        $actionId = $pauseEvents[1][1]['id'];

        $resumeEvents = sseEvents(
            $this->withToken($token)->post("/api/v1/actions/{$actionId}/reject")
                ->assertOk()->streamedContent()
        );

        expect(array_column($resumeEvents, 0))->toBe(['message.start', 'delta', 'message.end'])
            ->and(UserNote::find($note->id))->not->toBeNull()
            ->and(PendingAction::find($actionId)->status)->toBe(PendingAction::STATUS_REJECTED)
            ->and(AuditLog::where('tool_name', 'delete_note')->where('status', AuditLog::STATUS_REJECTED)->count())->toBe(1);

        Event::assertDispatched(ActionResolved::class, fn (ActionResolved $e) => $e->payload['status'] === 'rejected');
    });

    it('expires overdue actions after 10 minutes and isolates actions between users', function () {
        withPlatformModel();
        $fake = fakeLlm();
        [$user, $token] = userWithToken();
        [, $otherToken] = userWithToken(['email' => 'lain@example.com']);
        $note = $user->notes()->create(['title' => 'Simpan', 'content' => 'Tetap ada', 'tags' => []]);

        $fake->steps = [
            ['tool_calls' => [new LlmToolCall('call-del', 'delete_note', ['note_id' => $note->id])]],
        ];

        $conversation = $user->conversations()->create();
        $pauseEvents = sseEvents(
            $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", [
                'content' => 'Hapus catatan',
            ])->assertOk()->streamedContent()
        );
        $actionId = $pauseEvents[1][1]['id'];

        // Another user cannot see or resolve this action.
        auth()->forgetGuards();
        $this->withToken($otherToken)->postJson("/api/v1/actions/{$actionId}/approve")->assertNotFound();

        // After 11 minutes, action expires cleanly (410) and is logged to audit_logs.
        auth()->forgetGuards();
        $this->travel(11)->minutes();
        $this->withToken($token)->postJson("/api/v1/actions/{$actionId}/approve")
            ->assertStatus(410)
            ->assertJsonPath('code', 'action_expired');

        expect(UserNote::find($note->id))->not->toBeNull()
            ->and(PendingAction::find($actionId)->status)->toBe(PendingAction::STATUS_EXPIRED)
            ->and(AuditLog::where('tool_name', 'delete_note')->where('status', AuditLog::STATUS_EXPIRED)->count())->toBe(1);
    });
});

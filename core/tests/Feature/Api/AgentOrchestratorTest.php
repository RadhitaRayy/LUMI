<?php

require_once __DIR__.'/helpers.php';

use App\Llm\LlmException;
use App\Llm\LlmToolCall;
use App\Models\AppSetting;
use App\Models\AuditLog;
use App\Models\ToolCallRecord;
use App\Models\ToolPolicy;
use App\Models\UserMemory;
use App\Models\UserNote;
use Illuminate\Support\Facades\Http;

describe('tools catalog API', function () {
    it('lists available tools with modes and hides unconfigured web_search', function () {
        [, $token] = userWithToken();

        $res = $this->withToken($token)->getJson('/api/v1/tools')->assertOk();
        $names = collect($res->json('data'))->pluck('name')->all();

        expect($names)->toContain('get_time', 'search_notes', 'save_note', 'delete_note', 'remember_memory', 'forget_memory')
            ->and($names)->not->toContain('web_search');

        $byName = collect($res->json('data'))->keyBy('name');
        expect($byName['save_note']['mode'])->toBe('auto')
            ->and($byName['delete_note']['mode'])->toBe('ask');
    });

    it('includes web_search once enabled with an API key and respects ToolPolicy overrides', function () {
        AppSetting::current()->update([
            'web_search_driver' => 'tavily',
            'web_search_api_key' => 'tvly-secret-1234',
            'web_search_enabled' => true,
        ]);
        ToolPolicy::create([
            'tool_name' => 'save_note',
            'role' => 'user',
            'mode' => ToolPolicy::MODE_DISABLED,
            'is_enabled' => false,
        ]);

        [, $token] = userWithToken();
        $names = collect($this->withToken($token)->getJson('/api/v1/tools')->assertOk()->json('data'))->pluck('name')->all();

        expect($names)->toContain('web_search')
            ->and($names)->not->toContain('save_note');
    });
});

describe('agent orchestrator', function () {
    it('runs auto tools across steps, saves tool_calls and audit_logs, and streams the final answer', function () {
        withPlatformModel();
        $fake = fakeLlm();
        $fake->steps = [
            [
                'tool_calls' => [
                    new LlmToolCall('call-1', 'save_note', [
                        'title' => 'Ide Lumi',
                        'content' => 'Tambah orchestrator 5 langkah.',
                        'tags' => ['lumi', 'ai'],
                    ]),
                    new LlmToolCall('call-2', 'remember_memory', [
                        'content' => 'User prefers dark lime UI.',
                        'category' => 'preference',
                    ]),
                ],
                'input_tokens' => 40,
                'output_tokens' => 15,
            ],
            [
                'chunks' => ['Catatan ', 'dan memori sudah tersimpan!'],
                'input_tokens' => 80,
                'output_tokens' => 10,
            ],
        ];

        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();

        $response = $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", [
            'content' => 'Catat ide Lumi dan ingat aku suka tema dark lime',
        ]);
        $events = sseEvents($response->assertOk()->streamedContent());

        expect(array_column($events, 0))->toBe([
            'message.start',
            'tool.start',
            'tool.end',
            'tool.start',
            'tool.end',
            'delta',
            'delta',
            'message.end',
        ]);

        expect(UserNote::where('user_id', $user->id)->where('title', 'Ide Lumi')->exists())->toBeTrue()
            ->and(UserMemory::where('user_id', $user->id)->where('source', 'agent')->count())->toBe(1)
            ->and(ToolCallRecord::count())->toBe(2)
            ->and(AuditLog::where('status', AuditLog::STATUS_EXECUTED)->count())->toBe(2)
            ->and($fake->calls)->toHaveCount(2)
            ->and($fake->calls[1]['messages'][count($fake->calls[1]['messages']) - 1]['role'])->toBe('tool_result')
            ->and($events[7][1]['input_tokens'])->toBe(120)
            ->and($events[7][1]['output_tokens'])->toBe(25);

        // Reloading the conversation includes the persisted tool_calls on the assistant message.
        $conv = $this->withToken($token)->getJson("/api/v1/conversations/{$conversation->id}")->assertOk()->json('data');
        expect($conv['messages'][1]['tool_calls'])->toHaveCount(2);
    });

    it('refuses disabled tools in PHP and logs denial to audit_logs', function () {
        withPlatformModel();
        ToolPolicy::create([
            'tool_name' => 'save_note',
            'role' => 'user',
            'mode' => ToolPolicy::MODE_DISABLED,
            'is_enabled' => false,
        ]);

        $fake = fakeLlm();
        [$user, $token] = userWithToken();

        $fake->steps = [
            [
                'tool_calls' => [new LlmToolCall('call-dis', 'save_note', ['title' => 'Nope', 'content' => 'Blocked'])],
            ],
            [
                'chunks' => ['Tool simpan catatan sedang dinonaktifkan.'],
            ],
        ];

        $conversation = $user->conversations()->create();
        $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", [
            'content' => 'Simpan catatan',
        ])->assertOk()->streamedContent();

        expect(UserNote::where('user_id', $user->id)->count())->toBe(0)
            ->and(AuditLog::where('tool_name', 'save_note')->where('status', AuditLog::STATUS_DENIED)->count())->toBe(1);
    });

    it('skips tools when supports_tools is false and falls back gracefully on tools_unsupported error', function () {
        $model = withPlatformModel();
        $model->update(['supports_tools' => false]);
        $fake = fakeLlm(['Chat biasa tetap jalan.']);

        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();
        $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'Halo'])
            ->assertOk()->streamedContent();

        expect($fake->calls[0]['tools'])->toBeEmpty();

        // Now enable supports_tools but simulate provider rejecting tools on step 0.
        $model->update(['supports_tools' => true]);
        $fake2 = fakeLlm();
        $fake2->steps = [
            ['fail' => new LlmException(LlmException::TOOLS_UNSUPPORTED, 'No endpoints found that support tool use')],
            ['chunks' => ['Tetap bisa jawab tanpa tool!']],
        ];

        $events = sseEvents(
            $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'Tes fallback'])
                ->assertOk()->streamedContent()
        );

        expect(array_column($events, 0))->toBe(['message.start', 'notice', 'delta', 'message.end'])
            ->and($events[1][1]['code'])->toBe('tools_unsupported_fallback')
            ->and($fake2->calls)->toHaveCount(2)
            ->and($fake2->calls[0]['tools'])->not->toBeEmpty()
            ->and($fake2->calls[1]['tools'])->toBeEmpty();
    });

    it('runs web_search via Tavily when configured in AppSetting', function () {
        Http::fake([
            'api.tavily.com/*' => Http::response([
                'results' => [
                    ['title' => 'Laravel 13 Docs', 'url' => 'https://laravel.com', 'content' => 'Laravel 13 release notes.'],
                ],
            ]),
        ]);

        AppSetting::current()->update([
            'web_search_driver' => 'tavily',
            'web_search_api_key' => 'tvly-key-9999',
            'web_search_enabled' => true,
        ]);

        withPlatformModel();
        $fake = fakeLlm();
        $fake->steps = [
            ['tool_calls' => [new LlmToolCall('call-web', 'web_search', ['query' => 'Laravel 13'])]],
            ['chunks' => ['Menurut laravel.com, Laravel 13 sudah rilis.']],
        ];

        [$user, $token] = userWithToken();
        $conversation = $user->conversations()->create();
        $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'Cari info Laravel 13'])
            ->assertOk()->streamedContent();

        $toolResultMsg = $fake->calls[1]['messages'][count($fake->calls[1]['messages']) - 1];
        expect($toolResultMsg['results'][0]['result'])->toContain('Laravel 13 Docs');
    });
});

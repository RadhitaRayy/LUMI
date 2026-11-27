<?php

require_once __DIR__.'/helpers.php';

use App\Events\MemoryChanged;
use App\Events\NoteChanged;
use App\Models\UserMemory;
use App\Models\UserNote;
use Illuminate\Support\Facades\Event;

describe('memories API', function () {
    it('creates, lists, searches, updates, deletes memories and broadcasts changes', function () {
        Event::fake([MemoryChanged::class]);
        [$user, $token] = userWithToken();

        $id = $this->withToken($token)->postJson('/api/v1/memories', [
            'content' => 'Suka kopi hitam tanpa gula',
            'category' => 'preference',
        ])->assertCreated()
            ->assertJsonPath('data.category', 'preference')
            ->assertJsonPath('data.source', 'user')
            ->json('data.id');

        $this->withToken($token)->postJson('/api/v1/memories', [
            'content' => 'Developer Laravel di Windows',
            'category' => 'fact',
        ])->assertCreated();

        $this->withToken($token)->getJson('/api/v1/memories')
            ->assertOk()
            ->assertJsonPath('count', 2)
            ->assertJsonPath('limit', UserMemory::MAX_PER_USER)
            ->assertJsonCount(2, 'data');

        $this->withToken($token)->getJson('/api/v1/memories?q=kopi')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $id);

        $this->withToken($token)->patchJson("/api/v1/memories/{$id}", [
            'content' => 'Suka espresso dingin',
            'category' => 'context',
        ])->assertOk()
            ->assertJsonPath('data.content', 'Suka espresso dingin')
            ->assertJsonPath('data.category', 'context');

        $this->withToken($token)->deleteJson("/api/v1/memories/{$id}")->assertOk();
        expect(UserMemory::find($id))->toBeNull();

        Event::assertDispatched(MemoryChanged::class, 4);
    });

    it('enforces the 50-memory cap per user and isolates data between users', function () {
        [$user, $token] = userWithToken();
        [$other] = userWithToken(['email' => 'other@example.com']);
        $theirs = $other->memories()->create(['content' => 'Rahasia orang lain']);

        $this->withToken($token)->patchJson("/api/v1/memories/{$theirs->id}", ['content' => 'hack'])->assertNotFound();
        $this->withToken($token)->deleteJson("/api/v1/memories/{$theirs->id}")->assertNotFound();

        for ($i = 0; $i < UserMemory::MAX_PER_USER; $i++) {
            $user->memories()->create(['content' => "Fact #{$i}"]);
        }

        $this->withToken($token)->postJson('/api/v1/memories', ['content' => 'One too many'])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'memory_limit_reached');
    });

    it('injects the latest 20 stored memories automatically into chat prompts', function () {
        withPlatformModel();
        $fake = fakeLlm(['Noted!']);
        [$user, $token] = userWithToken();

        for ($i = 1; $i <= 23; $i++) {
            $this->travel(1)->seconds();
            $user->memories()->create(['content' => "SavedFact-{$i}"]);
        }

        $conversation = $user->conversations()->create();
        $this->withToken($token)->post("/api/v1/conversations/{$conversation->id}/messages", ['content' => 'Halo'])
            ->assertOk()->streamedContent();

        $system = $fake->calls[0]['system'];
        expect($system)->toContain("\n<user_memory>\n")
            ->and($system)->toContain('SavedFact-23')
            ->and($system)->toContain('SavedFact-4')
            ->and($system)->not->toContain("SavedFact-1\n")
            ->and($system)->not->toContain("SavedFact-3\n");
    });
});

describe('notes API', function () {
    it('creates, lists, searches by title/content/tag, updates, deletes and broadcasts changes', function () {
        Event::fake([NoteChanged::class]);
        [, $token] = userWithToken();

        $id = $this->withToken($token)->postJson('/api/v1/notes', [
            'title' => 'Checklist Deploy VPS',
            'content' => 'Siapkan Docker Compose dan Caddy.',
            'tags' => ['devops', ' vps ', 'devops', ''],
        ])->assertCreated()
            ->assertJsonPath('data.tags', ['devops', 'vps'])
            ->json('data.id');

        $this->withToken($token)->postJson('/api/v1/notes', [
            'title' => 'Resep Kopi',
            'content' => '18g biji kopi, 270ml air.',
            'tags' => ['minuman'],
        ])->assertCreated();

        $this->withToken($token)->getJson('/api/v1/notes')
            ->assertOk()
            ->assertJsonPath('meta.total', 2);

        $this->withToken($token)->getJson('/api/v1/notes?q=caddy')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $id);

        $this->withToken($token)->getJson('/api/v1/notes?q=minuman')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.title', 'Resep Kopi');

        $this->withToken($token)->patchJson("/api/v1/notes/{$id}", [
            'title' => 'Checklist VPS Production',
            'tags' => ['prod'],
        ])->assertOk()
            ->assertJsonPath('data.title', 'Checklist VPS Production')
            ->assertJsonPath('data.tags', ['prod']);

        $this->withToken($token)->deleteJson("/api/v1/notes/{$id}")->assertOk();
        expect(UserNote::find($id))->toBeNull();

        Event::assertDispatched(NoteChanged::class, 4);
    });

    it('isolates notes between users', function () {
        [, $token] = userWithToken();
        [$other] = userWithToken(['email' => 'lain@example.com']);
        $theirs = $other->notes()->create(['title' => 'Pribadi', 'content' => 'Rahasia', 'tags' => []]);

        $this->withToken($token)->patchJson("/api/v1/notes/{$theirs->id}", ['title' => 'Edit'])->assertNotFound();
        $this->withToken($token)->deleteJson("/api/v1/notes/{$theirs->id}")->assertNotFound();
        expect($this->withToken($token)->getJson('/api/v1/notes')->json('data'))->toBeEmpty();
    });
});

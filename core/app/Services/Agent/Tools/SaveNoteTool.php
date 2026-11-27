<?php

namespace App\Services\Agent\Tools;

use App\Enums\Role;
use App\Events\NoteChanged;
use App\Llm\LlmToolDefinition;
use App\Llm\LlmToolParam;
use App\Models\ToolPolicy;
use App\Models\User;
use App\Models\UserNote;
use Illuminate\Support\Str;

class SaveNoteTool implements AgentTool
{
    public function name(): string
    {
        return 'save_note';
    }

    public function label(): string
    {
        return __('Save note');
    }

    public function description(): string
    {
        return __('Create or update a personal note in your account.');
    }

    public function defaultMode(Role $role): string
    {
        return ToolPolicy::MODE_AUTO;
    }

    public function isAvailable(): bool
    {
        return true;
    }

    public function definition(): LlmToolDefinition
    {
        return new LlmToolDefinition(
            name: $this->name(),
            description: 'Save a new personal note or update an existing one (when note_id is provided).',
            parameters: [
                new LlmToolParam('title', 'string', 'Short note title (max 120 characters).'),
                new LlmToolParam('content', 'string', 'Full note body.'),
                new LlmToolParam('tags', 'array_string', 'Optional short tags (up to 10).', required: false),
                new LlmToolParam('note_id', 'string', 'Optional existing note ID to update.', required: false),
            ],
        );
    }

    public function execute(User $user, array $arguments): ToolExecutionResult
    {
        $title = is_string($arguments['title'] ?? null) ? trim($arguments['title']) : '';
        $content = is_string($arguments['content'] ?? null) ? trim($arguments['content']) : '';
        $noteId = is_string($arguments['note_id'] ?? null) ? trim($arguments['note_id']) : '';

        if ($title === '' || $content === '') {
            return ToolExecutionResult::error('Both title and content are required.', __('Missing title or content'));
        }

        $title = Str::limit($title, UserNote::MAX_TITLE_LENGTH, '');
        $content = Str::limit($content, UserNote::MAX_CONTENT_LENGTH, '');

        $tags = [];
        if (is_array($arguments['tags'] ?? null)) {
            foreach ($arguments['tags'] as $tag) {
                if (! is_string($tag)) {
                    continue;
                }
                $clean = Str::limit(trim($tag), UserNote::MAX_TAG_LENGTH, '');
                if ($clean !== '' && ! in_array($clean, $tags, true) && count($tags) < UserNote::MAX_TAGS) {
                    $tags[] = $clean;
                }
            }
        }

        if ($noteId !== '') {
            /** @var UserNote|null $existing */
            $existing = $user->notes()->whereKey($noteId)->first();
            if ($existing === null) {
                return ToolExecutionResult::error("Note {$noteId} was not found.", __('Note not found'));
            }
            $existing->update(['title' => $title, 'content' => $content, 'tags' => $tags]);
            broadcast(NoteChanged::updated($existing));

            return ToolExecutionResult::ok(
                "Updated note {$existing->id}: \"{$existing->title}\".",
                __('Updated ":title"', ['title' => $existing->title]),
            );
        }

        /** @var UserNote $note */
        $note = $user->notes()->create([
            'title' => $title,
            'content' => $content,
            'tags' => $tags,
        ]);
        broadcast(NoteChanged::created($note));

        return ToolExecutionResult::ok(
            "Saved note {$note->id}: \"{$note->title}\".",
            __('Saved ":title"', ['title' => $note->title]),
        );
    }
}

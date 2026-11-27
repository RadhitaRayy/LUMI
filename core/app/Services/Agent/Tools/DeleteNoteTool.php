<?php

namespace App\Services\Agent\Tools;

use App\Enums\Role;
use App\Events\NoteChanged;
use App\Llm\LlmToolDefinition;
use App\Llm\LlmToolParam;
use App\Models\ToolPolicy;
use App\Models\User;
use App\Models\UserNote;

class DeleteNoteTool implements AgentTool
{
    public function name(): string
    {
        return 'delete_note';
    }

    public function label(): string
    {
        return __('Delete note');
    }

    public function description(): string
    {
        return __('Permanently delete a personal note (asks for approval first).');
    }

    public function defaultMode(Role $role): string
    {
        return ToolPolicy::MODE_ASK;
    }

    public function isAvailable(): bool
    {
        return true;
    }

    public function definition(): LlmToolDefinition
    {
        return new LlmToolDefinition(
            name: $this->name(),
            description: 'Permanently delete one of the user\'s saved notes by its ID. Always requires user approval.',
            parameters: [
                new LlmToolParam('note_id', 'string', 'ID of the note to delete.'),
            ],
        );
    }

    public function execute(User $user, array $arguments): ToolExecutionResult
    {
        $noteId = is_string($arguments['note_id'] ?? null) ? trim($arguments['note_id']) : '';
        if ($noteId === '') {
            return ToolExecutionResult::error('note_id is required.', __('Missing note ID'));
        }

        /** @var UserNote|null $note */
        $note = $user->notes()->whereKey($noteId)->first();
        if ($note === null) {
            return ToolExecutionResult::error("Note {$noteId} was not found.", __('Note not found'));
        }

        $title = $note->title;
        $id = $note->id;
        $note->delete();
        broadcast(NoteChanged::deleted($user->id, $id));

        return ToolExecutionResult::ok(
            "Deleted note {$id} (\"{$title}\").",
            __('Deleted ":title"', ['title' => $title]),
        );
    }
}

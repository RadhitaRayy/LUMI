<?php

namespace App\Services\Agent\Tools;

use App\Enums\Role;
use App\Llm\LlmToolDefinition;
use App\Llm\LlmToolParam;
use App\Models\ToolPolicy;
use App\Models\User;
use App\Models\UserNote;
use Illuminate\Support\Str;

class SearchNotesTool implements AgentTool
{
    public function name(): string
    {
        return 'search_notes';
    }

    public function label(): string
    {
        return __('Search notes');
    }

    public function description(): string
    {
        return __('Search your saved personal notes by keyword or tag.');
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
            description: 'Search the user\'s saved notes by title, content, or tag. Leave query empty to list recent notes.',
            parameters: [
                new LlmToolParam(
                    name: 'query',
                    type: 'string',
                    description: 'Keyword or tag to search for (optional).',
                    required: false,
                ),
            ],
        );
    }

    public function execute(User $user, array $arguments): ToolExecutionResult
    {
        $q = is_string($arguments['query'] ?? null) ? trim($arguments['query']) : '';

        $query = $user->notes()->latest('updated_at')->latest('id');
        if ($q !== '') {
            $pattern = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $q).'%';
            $query->where(function ($sub) use ($pattern) {
                $sub->whereLike('title', $pattern)
                    ->orWhereLike('content', $pattern)
                    ->orWhereRaw('tags::text ILIKE ?', [$pattern]);
            });
        }

        $notes = $query->limit(10)->get();

        if ($notes->isEmpty()) {
            return ToolExecutionResult::ok(
                $q === '' ? 'No notes saved yet.' : "No notes matched \"{$q}\".",
                __('No matching notes'),
            );
        }

        $lines = $notes->map(function (UserNote $n): string {
            $tags = $n->tags !== [] ? ' ['.implode(', ', $n->tags).']' : '';
            $excerpt = Str::limit(Str::squish($n->content), 240);

            return "- ID: {$n->id} | Title: {$n->title}{$tags}\n  {$excerpt}";
        })->implode("\n");

        return ToolExecutionResult::ok(
            "Found {$notes->count()} note(s):\n{$lines}",
            trans_choice(':count note found|:count notes found', $notes->count(), ['count' => $notes->count()]),
        );
    }
}

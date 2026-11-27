<?php

namespace App\Services\Agent\Tools;

use App\Enums\Role;
use App\Events\MemoryChanged;
use App\Llm\LlmToolDefinition;
use App\Llm\LlmToolParam;
use App\Models\ToolPolicy;
use App\Models\User;
use App\Models\UserMemory;
use Illuminate\Support\Str;

class RememberMemoryTool implements AgentTool
{
    public function name(): string
    {
        return 'remember_memory';
    }

    public function label(): string
    {
        return __('Save memory');
    }

    public function description(): string
    {
        return __('Remember a lasting preference or fact across future chats.');
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
            description: 'Save a concise, lasting preference, fact, or context about the user (never save secrets or throwaway chat details).',
            parameters: [
                new LlmToolParam('content', 'string', 'One short sentence describing the fact or preference (max 300 chars).'),
                new LlmToolParam('category', 'enum', 'Category of the memory.', required: false, enum: UserMemory::CATEGORIES),
            ],
        );
    }

    public function execute(User $user, array $arguments): ToolExecutionResult
    {
        $content = is_string($arguments['content'] ?? null) ? trim($arguments['content']) : '';
        if ($content === '') {
            return ToolExecutionResult::error('Memory content cannot be empty.', __('Empty memory'));
        }

        $content = Str::limit($content, UserMemory::MAX_CONTENT_LENGTH, '');
        $category = is_string($arguments['category'] ?? null) && in_array($arguments['category'], UserMemory::CATEGORIES, true)
            ? $arguments['category']
            : UserMemory::CATEGORY_FACT;

        // Deduplicate exact match (case-insensitive) by touching its timestamp/category.
        /** @var UserMemory|null $duplicate */
        $duplicate = $user->memories()->whereRaw('LOWER(content) = LOWER(?)', [$content])->first();
        if ($duplicate !== null) {
            $duplicate->forceFill(['category' => $category, 'updated_at' => now()])->save();
            broadcast(MemoryChanged::updated($duplicate));

            return ToolExecutionResult::ok(
                "Memory already recorded (ID: {$duplicate->id}).",
                Str::limit($duplicate->content, 80),
            );
        }

        if ($user->memories()->count() >= UserMemory::MAX_PER_USER) {
            return ToolExecutionResult::error(
                'Memory limit reached ('.UserMemory::MAX_PER_USER.' items). Ask the user to delete an older memory first.',
                __('Memory limit reached'),
            );
        }

        /** @var UserMemory $memory */
        $memory = $user->memories()->create([
            'content' => $content,
            'category' => $category,
            'source' => UserMemory::SOURCE_AGENT,
        ]);
        broadcast(MemoryChanged::created($memory));

        return ToolExecutionResult::ok(
            "Remembered (ID: {$memory->id}): {$memory->content}",
            Str::limit($memory->content, 80),
        );
    }
}

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

class ForgetMemoryTool implements AgentTool
{
    public function name(): string
    {
        return 'forget_memory';
    }

    public function label(): string
    {
        return __('Forget memory');
    }

    public function description(): string
    {
        return __('Delete a saved memory from your account (asks for approval first).');
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
            description: 'Delete one of the user\'s stored memories by its ID. Always requires user approval.',
            parameters: [
                new LlmToolParam('memory_id', 'string', 'ID of the memory to delete.'),
            ],
        );
    }

    public function execute(User $user, array $arguments): ToolExecutionResult
    {
        $memoryId = is_string($arguments['memory_id'] ?? null) ? trim($arguments['memory_id']) : '';
        if ($memoryId === '') {
            return ToolExecutionResult::error('memory_id is required.', __('Missing memory ID'));
        }

        /** @var UserMemory|null $memory */
        $memory = $user->memories()->whereKey($memoryId)->first();
        if ($memory === null) {
            return ToolExecutionResult::error("Memory {$memoryId} was not found.", __('Memory not found'));
        }

        $preview = Str::limit($memory->content, 60);
        $id = $memory->id;
        $memory->delete();
        broadcast(MemoryChanged::deleted($user->id, $id));

        return ToolExecutionResult::ok(
            "Forgot memory {$id}.",
            __('Forgot ":content"', ['content' => $preview]),
        );
    }
}

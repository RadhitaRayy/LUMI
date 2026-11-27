<?php

namespace App\Services\Agent;

use App\Enums\Role;
use App\Llm\LlmToolDefinition;
use App\Models\ToolPolicy;
use App\Models\User;
use App\Services\Agent\Tools\AgentTool;
use App\Services\Agent\Tools\DeleteNoteTool;
use App\Services\Agent\Tools\ForgetMemoryTool;
use App\Services\Agent\Tools\GetTimeTool;
use App\Services\Agent\Tools\RememberMemoryTool;
use App\Services\Agent\Tools\SaveNoteTool;
use App\Services\Agent\Tools\SearchNotesTool;
use App\Services\Agent\Tools\WebSearchTool;

/**
 * Central catalog of server-side agent tools and their PHP-enforced per-role policies.
 */
class ToolRegistry
{
    /** @var array<string, AgentTool> */
    private array $tools = [];

    public function __construct()
    {
        $builtIn = [
            new GetTimeTool,
            new SearchNotesTool,
            new SaveNoteTool,
            new DeleteNoteTool,
            new RememberMemoryTool,
            new ForgetMemoryTool,
            new WebSearchTool,
        ];

        foreach ($builtIn as $tool) {
            $this->tools[$tool->name()] = $tool;
        }
    }

    /** @return list<AgentTool> */
    public function all(): array
    {
        return array_values($this->tools);
    }

    public function find(string $name): ?AgentTool
    {
        return $this->tools[$name] ?? null;
    }

    /**
     * Effective policy mode (`auto` | `ask` | `disabled`) for one tool and role.
     */
    public function resolveMode(string $toolName, Role $role): string
    {
        $tool = $this->find($toolName);
        if ($tool === null || ! $tool->isAvailable()) {
            return ToolPolicy::MODE_DISABLED;
        }

        $override = ToolPolicy::query()
            ->where('tool_name', $toolName)
            ->where('role', $role->value)
            ->first();

        if ($override !== null) {
            if (! $override->is_enabled) {
                return ToolPolicy::MODE_DISABLED;
            }

            return in_array($override->mode, ToolPolicy::MODES, true)
                ? $override->mode
                : ToolPolicy::MODE_DISABLED;
        }

        return $tool->defaultMode($role);
    }

    /**
     * Tool definitions offered to the LLM for this user (excludes disabled/unconfigured tools).
     *
     * @return list<LlmToolDefinition>
     */
    public function definitionsFor(User $user): array
    {
        $defs = [];
        foreach ($this->tools as $tool) {
            if ($this->resolveMode($tool->name(), $user->role) !== ToolPolicy::MODE_DISABLED) {
                $defs[] = $tool->definition();
            }
        }

        return $defs;
    }

    /**
     * Localized tool list for `GET /api/v1/tools`.
     *
     * @return list<array{name: string, label: string, description: string, mode: string}>
     */
    public function catalogFor(User $user): array
    {
        $list = [];
        foreach ($this->tools as $tool) {
            $mode = $this->resolveMode($tool->name(), $user->role);
            if ($mode === ToolPolicy::MODE_DISABLED) {
                continue;
            }
            $list[] = [
                'name' => $tool->name(),
                'label' => $tool->label(),
                'description' => $tool->description(),
                'mode' => $mode,
            ];
        }

        return $list;
    }
}

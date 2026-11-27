<?php

namespace App\Services\Agent\Tools;

use App\Enums\Role;
use App\Llm\LlmToolDefinition;
use App\Models\User;

interface AgentTool
{
    public function name(): string;

    /** Short localized display label shown in ToolCallCard and the Tools screen. */
    public function label(): string;

    /** Short localized description shown in the Tools screen and Console. */
    public function description(): string;

    /** Default mode (`auto` | `ask` | `disabled`) when no ToolPolicy override exists. */
    public function defaultMode(Role $role): string;

    /** False when the tool requires external configuration that is not set (e.g. web_search key). */
    public function isAvailable(): bool;

    public function definition(): LlmToolDefinition;

    /**
     * Execute the tool strictly scoped to [$user].
     *
     * @param  array<string, mixed>  $arguments
     */
    public function execute(User $user, array $arguments): ToolExecutionResult;
}

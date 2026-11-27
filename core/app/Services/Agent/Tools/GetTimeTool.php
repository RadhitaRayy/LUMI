<?php

namespace App\Services\Agent\Tools;

use App\Enums\Role;
use App\Llm\LlmToolDefinition;
use App\Llm\LlmToolParam;
use App\Models\ToolPolicy;
use App\Models\User;
use DateTimeZone;
use Throwable;

class GetTimeTool implements AgentTool
{
    public function name(): string
    {
        return 'get_time';
    }

    public function label(): string
    {
        return __('Check current time');
    }

    public function description(): string
    {
        return __('Read the current date, day, and time for a timezone.');
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
            description: 'Get the current date, day of week, and time. Defaults to Asia/Jakarta (WIB).',
            parameters: [
                new LlmToolParam(
                    name: 'timezone',
                    type: 'string',
                    description: 'Optional IANA timezone, e.g. Asia/Jakarta or UTC.',
                    required: false,
                ),
            ],
        );
    }

    public function execute(User $user, array $arguments): ToolExecutionResult
    {
        $tz = is_string($arguments['timezone'] ?? null) && trim($arguments['timezone']) !== ''
            ? trim($arguments['timezone'])
            : 'Asia/Jakarta';

        try {
            new DateTimeZone($tz);
        } catch (Throwable) {
            return ToolExecutionResult::error(
                "Invalid timezone: {$tz}. Use a valid IANA timezone like Asia/Jakarta or UTC.",
                __('Invalid timezone'),
            );
        }

        $now = now($tz);
        $formatted = $now->format('l, Y-m-d H:i:s T');

        return ToolExecutionResult::ok(
            "Current time ({$tz}): {$formatted}",
            $now->format('Y-m-d H:i')." ({$tz})",
        );
    }
}

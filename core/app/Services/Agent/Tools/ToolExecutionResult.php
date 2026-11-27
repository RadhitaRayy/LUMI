<?php

namespace App\Services\Agent\Tools;

/**
 * Outcome of running one agent tool.
 */
final readonly class ToolExecutionResult
{
    public function __construct(
        public bool $ok,
        public string $output,
        public string $summary,
    ) {}

    public static function ok(string $output, string $summary): self
    {
        return new self(true, $output, $summary);
    }

    public static function error(string $output, string $summary): self
    {
        return new self(false, $output, $summary);
    }
}

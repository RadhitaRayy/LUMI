<?php

namespace App\Llm;

/**
 * A tool call requested by the model during a turn.
 */
final readonly class LlmToolCall
{
    /**
     * @param  array<string, mixed>  $arguments
     */
    public function __construct(
        public string $id,
        public string $name,
        public array $arguments = [],
    ) {}
}

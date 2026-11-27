<?php

namespace App\Llm;

/**
 * Provider-agnostic tool schema passed to ChatDriver.
 */
final readonly class LlmToolDefinition
{
    /**
     * @param  list<LlmToolParam>  $parameters
     */
    public function __construct(
        public string $name,
        public string $description,
        public array $parameters = [],
    ) {}
}

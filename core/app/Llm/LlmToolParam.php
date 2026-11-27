<?php

namespace App\Llm;

/**
 * One parameter of a tool exposed to the LLM.
 */
final readonly class LlmToolParam
{
    /**
     * @param  list<string>  $enum
     */
    public function __construct(
        public string $name,
        public string $type, // string | array_string | enum
        public string $description,
        public bool $required = true,
        public array $enum = [],
    ) {}
}

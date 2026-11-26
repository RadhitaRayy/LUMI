<?php

namespace App\Llm;

/**
 * A piece of a streamed answer: a text delta, or the final token usage.
 */
final readonly class LlmEvent
{
    private function __construct(
        public string $type,
        public string $text = '',
        public int $inputTokens = 0,
        public int $outputTokens = 0,
    ) {}

    public static function delta(string $text): self
    {
        return new self('delta', text: $text);
    }

    public static function end(int $inputTokens, int $outputTokens): self
    {
        return new self('end', inputTokens: $inputTokens, outputTokens: $outputTokens);
    }

    public function isDelta(): bool
    {
        return $this->type === 'delta';
    }
}

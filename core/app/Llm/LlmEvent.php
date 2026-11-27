<?php

namespace App\Llm;

/**
 * A piece of a streamed model step: a text delta, a requested tool call, or the final token usage.
 */
final readonly class LlmEvent
{
    private function __construct(
        public string $type,
        public string $text = '',
        public ?LlmToolCall $toolCall = null,
        public int $inputTokens = 0,
        public int $outputTokens = 0,
    ) {}

    public static function delta(string $text): self
    {
        return new self('delta', text: $text);
    }

    public static function toolCall(LlmToolCall $call): self
    {
        return new self('tool_call', toolCall: $call);
    }

    public static function end(int $inputTokens, int $outputTokens): self
    {
        return new self('end', inputTokens: $inputTokens, outputTokens: $outputTokens);
    }

    public function isDelta(): bool
    {
        return $this->type === 'delta';
    }

    public function isToolCall(): bool
    {
        return $this->type === 'tool_call' && $this->toolCall !== null;
    }
}

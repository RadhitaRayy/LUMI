<?php

namespace App\Llm;

/**
 * Scripted driver for tests: no network, records every call (including tools offered).
 */
class FakeChatDriver implements ChatDriver
{
    /** @var list<array{model: ResolvedModel, system: string, messages: list<array<string, mixed>>, tools: list<LlmToolDefinition>}> */
    public array $calls = [];

    /** @var list<ResolvedModel> */
    public array $pings = [];

    /**
     * Optional per-step scripts: each entry is `['chunks' => list<string>, 'tool_calls' => list<LlmToolCall>, 'fail' => ?LlmException]`.
     *
     * @var list<array{chunks?: list<string>, tool_calls?: list<LlmToolCall>, fail?: ?LlmException, input_tokens?: int, output_tokens?: int}>
     */
    public array $steps = [];

    private int $stepIndex = 0;

    /**
     * @param  list<string>  $chunks
     */
    public function __construct(
        public array $chunks = ['Halo', ', aku ', 'Lumi.'],
        public ?LlmException $failWith = null,
        public ?LlmException $failPingWith = null,
        public int $inputTokens = 12,
        public int $outputTokens = 5,
    ) {}

    public function stream(ResolvedModel $model, string $systemPrompt, array $messages, array $tools = []): iterable
    {
        $this->calls[] = ['model' => $model, 'system' => $systemPrompt, 'messages' => $messages, 'tools' => $tools];

        if ($this->steps !== []) {
            $step = $this->steps[$this->stepIndex] ?? end($this->steps);
            $this->stepIndex++;

            foreach ($step['chunks'] ?? [] as $chunk) {
                yield LlmEvent::delta($chunk);
            }

            foreach ($step['tool_calls'] ?? [] as $call) {
                yield LlmEvent::toolCall($call);
            }

            if (($step['fail'] ?? null) instanceof LlmException) {
                throw $step['fail'];
            }

            yield LlmEvent::end($step['input_tokens'] ?? $this->inputTokens, $step['output_tokens'] ?? $this->outputTokens);

            return;
        }

        foreach ($this->chunks as $chunk) {
            yield LlmEvent::delta($chunk);
        }

        if ($this->failWith !== null) {
            throw $this->failWith;
        }

        yield LlmEvent::end($this->inputTokens, $this->outputTokens);
    }

    public function ping(ResolvedModel $model): void
    {
        $this->pings[] = $model;

        if ($this->failPingWith !== null) {
            throw $this->failPingWith;
        }
    }
}

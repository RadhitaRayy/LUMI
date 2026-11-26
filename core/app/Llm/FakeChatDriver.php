<?php

namespace App\Llm;

/**
 * Scripted driver for tests: no network, records what it was asked.
 */
class FakeChatDriver implements ChatDriver
{
    /** @var list<array{model: ResolvedModel, system: string, messages: array<int, array{role: string, content: string}>}> */
    public array $calls = [];

    /** @var list<ResolvedModel> */
    public array $pings = [];

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

    public function stream(ResolvedModel $model, string $systemPrompt, array $messages): iterable
    {
        $this->calls[] = ['model' => $model, 'system' => $systemPrompt, 'messages' => $messages];

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

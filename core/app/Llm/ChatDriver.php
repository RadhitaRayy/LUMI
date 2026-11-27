<?php

namespace App\Llm;

interface ChatDriver
{
    /**
     * Stream one model step (text deltas, optional tool call requests, and token usage).
     *
     * @param  list<array<string, mixed>>  $messages  oldest first (`user`, `assistant`, or `tool_result`)
     * @param  list<LlmToolDefinition>  $tools  tool schemas offered in this step
     * @return iterable<LlmEvent>
     *
     * @throws LlmException
     */
    public function stream(ResolvedModel $model, string $systemPrompt, array $messages, array $tools = []): iterable;

    /**
     * Make a tiny request to check that the key and model work.
     *
     * @throws LlmException
     */
    public function ping(ResolvedModel $model): void;
}

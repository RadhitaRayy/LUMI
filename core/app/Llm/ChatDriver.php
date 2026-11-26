<?php

namespace App\Llm;

interface ChatDriver
{
    /**
     * Stream an answer.
     *
     * @param  list<array{role: string, content: string}>  $messages  oldest first, last one from the user
     * @return iterable<LlmEvent>
     *
     * @throws LlmException
     */
    public function stream(ResolvedModel $model, string $systemPrompt, array $messages): iterable;

    /**
     * Make a tiny request to check that the key and model work.
     *
     * @throws LlmException
     */
    public function ping(ResolvedModel $model): void;
}

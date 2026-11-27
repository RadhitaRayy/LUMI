<?php

namespace App\Llm;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Prism\Prism\Exceptions\PrismException;
use Prism\Prism\Exceptions\PrismProviderOverloadedException;
use Prism\Prism\Exceptions\PrismRateLimitedException;
use Prism\Prism\Exceptions\PrismServerException;
use Prism\Prism\Facades\Prism;
use Prism\Prism\Schema\StringSchema;
use Prism\Prism\Streaming\Events\ErrorEvent;
use Prism\Prism\Streaming\Events\StreamEndEvent;
use Prism\Prism\Streaming\Events\TextDeltaEvent;
use Prism\Prism\Streaming\Events\ToolCallEvent;
use Prism\Prism\Text\PendingRequest;
use Prism\Prism\Tool;
use Prism\Prism\ValueObjects\Messages\AssistantMessage;
use Prism\Prism\ValueObjects\Messages\ToolResultMessage;
use Prism\Prism\ValueObjects\Messages\UserMessage;
use Prism\Prism\ValueObjects\ToolCall;
use Prism\Prism\ValueObjects\ToolResult;
use Throwable;

/**
 * Talks to OpenAI-compatible chat-completions APIs through Prism.
 *
 * Both drivers go through Prism's OpenRouter provider, which speaks plain
 * `chat/completions` with a configurable base URL. Tool execution itself is
 * owned by Lumi's AgentOrchestrator (one step per call, PHP-enforced policy).
 */
class PrismChatDriver implements ChatDriver
{
    private const OPENROUTER_URL = 'https://openrouter.ai/api/v1';

    private const MAX_TOKENS = 2048;

    public function stream(ResolvedModel $model, string $systemPrompt, array $messages, array $tools = []): iterable
    {
        $request = $this->request($model)
            ->withSystemPrompt($systemPrompt)
            ->withMessages($this->mapMessages($messages))
            ->withMaxTokens(self::MAX_TOKENS)
            ->withMaxSteps(1);

        if ($tools !== []) {
            $request = $request->withTools(array_map($this->mapTool(...), $tools));
        }

        try {
            foreach ($request->asStream() as $event) {
                if ($event instanceof TextDeltaEvent && $event->delta !== '') {
                    yield LlmEvent::delta($event->delta);
                } elseif ($event instanceof ToolCallEvent) {
                    yield LlmEvent::toolCall(new LlmToolCall(
                        id: $event->toolCall->id,
                        name: $event->toolCall->name,
                        arguments: $event->toolCall->arguments(),
                    ));
                } elseif ($event instanceof StreamEndEvent) {
                    yield LlmEvent::end(
                        $event->usage->promptTokens ?? 0,
                        $event->usage->completionTokens ?? 0,
                    );
                } elseif ($event instanceof ErrorEvent && ! $event->recoverable) {
                    throw new LlmException($this->classifyErrorMessage($event->message), $event->message);
                }
            }
        } catch (LlmException $e) {
            throw $e;
        } catch (Throwable $e) {
            throw $this->translate($e);
        }
    }

    public function ping(ResolvedModel $model): void
    {
        try {
            $this->request($model)
                ->withPrompt('Balas dengan satu kata: ok')
                ->withMaxTokens(5)
                ->asText();
        } catch (Throwable $e) {
            throw $this->translate($e);
        }
    }

    private function request(ResolvedModel $model): PendingRequest
    {
        return Prism::text()
            ->using('openrouter', $model->modelId, [
                'api_key' => $model->apiKey,
                'url' => rtrim($model->baseUrl ?: self::OPENROUTER_URL, '/'),
            ])
            ->withClientOptions(['timeout' => 120, 'connect_timeout' => 10]);
    }

    /**
     * @param  list<array<string, mixed>>  $messages
     * @return list<AssistantMessage|ToolResultMessage|UserMessage>
     */
    private function mapMessages(array $messages): array
    {
        $mapped = [];

        foreach ($messages as $m) {
            $role = (string) ($m['role'] ?? 'user');

            if ($role === 'tool_result') {
                $results = [];
                $rawResults = is_array($m['results'] ?? null) ? $m['results'] : [];
                foreach ($rawResults as $r) {
                    if (! is_array($r)) {
                        continue;
                    }
                    $results[] = new ToolResult(
                        toolCallId: (string) ($r['tool_call_id'] ?? ''),
                        toolName: (string) ($r['tool_name'] ?? ''),
                        args: is_array($r['args'] ?? null) ? $r['args'] : [],
                        result: (string) ($r['result'] ?? ''),
                    );
                }
                $mapped[] = new ToolResultMessage($results);

                continue;
            }

            if ($role === 'assistant') {
                $toolCalls = [];
                $rawCalls = is_array($m['tool_calls'] ?? null) ? $m['tool_calls'] : [];
                foreach ($rawCalls as $tc) {
                    if (! is_array($tc)) {
                        continue;
                    }
                    $toolCalls[] = new ToolCall(
                        id: (string) ($tc['id'] ?? ''),
                        name: (string) ($tc['name'] ?? ''),
                        arguments: is_array($tc['arguments'] ?? null) ? $tc['arguments'] : [],
                    );
                }
                $mapped[] = new AssistantMessage((string) ($m['content'] ?? ''), $toolCalls);

                continue;
            }

            $mapped[] = new UserMessage((string) ($m['content'] ?? ''));
        }

        return $mapped;
    }

    /**
     * Builds a schema-only Prism Tool; Lumi's AgentOrchestrator enforces policy and runs tools itself.
     */
    private function mapTool(LlmToolDefinition $definition): Tool
    {
        $tool = (new Tool)
            ->as($definition->name)
            ->for($definition->description)
            ->using(static fn (): string => '');

        foreach ($definition->parameters as $param) {
            if ($param->type === 'enum' && $param->enum !== []) {
                $tool->withEnumParameter($param->name, $param->description, $param->enum, $param->required);
            } elseif ($param->type === 'array_string') {
                $tool->withArrayParameter(
                    $param->name,
                    $param->description,
                    new StringSchema('item', 'One item'),
                    $param->required,
                );
            } else {
                $tool->withStringParameter($param->name, $param->description, $param->required);
            }
        }

        return $tool;
    }

    private function translate(Throwable $e): LlmException
    {
        $status = $this->statusOf($e);
        $message = $e->getMessage();

        if (in_array($status, [400, 404, 422], true) && $this->looksLikeToolsUnsupported($message)) {
            return new LlmException(LlmException::TOOLS_UNSUPPORTED, $message, $e);
        }

        $code = match (true) {
            $e instanceof PrismRateLimitedException, $status === 429 => LlmException::RATE_LIMITED,
            $e instanceof PrismProviderOverloadedException, $e instanceof PrismServerException,
            in_array($status, [500, 502, 503, 504], true) => LlmException::UNAVAILABLE,
            in_array($status, [401, 402, 403], true) => LlmException::KEY_INVALID,
            $status === 404 => LlmException::MODEL_NOT_FOUND,
            $this->isConnectionProblem($e) => LlmException::UNREACHABLE,
            default => LlmException::ERROR,
        };

        return new LlmException($code, $message, $e);
    }

    private function classifyErrorMessage(string $message): string
    {
        return $this->looksLikeToolsUnsupported($message)
            ? LlmException::TOOLS_UNSUPPORTED
            : LlmException::ERROR;
    }

    private function looksLikeToolsUnsupported(string $message): bool
    {
        $lower = strtolower($message);

        return str_contains($lower, 'tool') && (
            str_contains($lower, 'not support')
            || str_contains($lower, 'unsupported')
            || str_contains($lower, 'does not support')
            || str_contains($lower, 'no endpoints found that support tool')
        );
    }

    private function statusOf(Throwable $e): ?int
    {
        for ($cur = $e; $cur !== null; $cur = $cur->getPrevious()) {
            if ($cur instanceof PrismException && $cur->httpStatus !== null) {
                return $cur->httpStatus;
            }
            if ($cur instanceof RequestException) {
                return $cur->response->status();
            }
        }

        return null;
    }

    private function isConnectionProblem(Throwable $e): bool
    {
        for ($cur = $e; $cur !== null; $cur = $cur->getPrevious()) {
            if ($cur instanceof ConnectionException) {
                return true;
            }
        }

        return false;
    }
}

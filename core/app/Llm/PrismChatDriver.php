<?php

namespace App\Llm;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Prism\Prism\Exceptions\PrismException;
use Prism\Prism\Exceptions\PrismProviderOverloadedException;
use Prism\Prism\Exceptions\PrismRateLimitedException;
use Prism\Prism\Exceptions\PrismServerException;
use Prism\Prism\Facades\Prism;
use Prism\Prism\Streaming\Events\ErrorEvent;
use Prism\Prism\Streaming\Events\StreamEndEvent;
use Prism\Prism\Streaming\Events\TextDeltaEvent;
use Prism\Prism\Text\PendingRequest;
use Prism\Prism\ValueObjects\Messages\AssistantMessage;
use Prism\Prism\ValueObjects\Messages\UserMessage;
use Throwable;

/**
 * Talks to OpenAI-compatible chat-completions APIs through Prism.
 *
 * Both drivers go through Prism's OpenRouter provider, which speaks plain
 * `chat/completions` with a configurable base URL. Prism's `openai` provider
 * uses the Responses API, which NVIDIA NIM and most compatible servers lack.
 */
class PrismChatDriver implements ChatDriver
{
    private const OPENROUTER_URL = 'https://openrouter.ai/api/v1';

    private const MAX_TOKENS = 2048;

    public function stream(ResolvedModel $model, string $systemPrompt, array $messages): iterable
    {
        $request = $this->request($model)
            ->withSystemPrompt($systemPrompt)
            ->withMessages(array_map(
                fn (array $m) => $m['role'] === 'assistant'
                    ? new AssistantMessage($m['content'])
                    : new UserMessage($m['content']),
                $messages,
            ))
            ->withMaxTokens(self::MAX_TOKENS);

        try {
            foreach ($request->asStream() as $event) {
                if ($event instanceof TextDeltaEvent && $event->delta !== '') {
                    yield LlmEvent::delta($event->delta);
                } elseif ($event instanceof StreamEndEvent) {
                    yield LlmEvent::end(
                        $event->usage->promptTokens ?? 0,
                        $event->usage->completionTokens ?? 0,
                    );
                } elseif ($event instanceof ErrorEvent && ! $event->recoverable) {
                    throw new LlmException(LlmException::ERROR, $event->message);
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

    private function translate(Throwable $e): LlmException
    {
        $status = $this->statusOf($e);

        $code = match (true) {
            $e instanceof PrismRateLimitedException, $status === 429 => LlmException::RATE_LIMITED,
            $e instanceof PrismProviderOverloadedException, $e instanceof PrismServerException,
            in_array($status, [500, 502, 503, 504], true) => LlmException::UNAVAILABLE,
            in_array($status, [401, 402, 403], true) => LlmException::KEY_INVALID,
            $status === 404 => LlmException::MODEL_NOT_FOUND,
            $this->isConnectionProblem($e) => LlmException::UNREACHABLE,
            default => LlmException::ERROR,
        };

        return new LlmException($code, $e->getMessage(), $e);
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

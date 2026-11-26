<?php

namespace App\Llm;

use RuntimeException;
use Throwable;

/**
 * A provider call failed. `errorCode` is one of the constants below.
 */
class LlmException extends RuntimeException
{
    public const KEY_INVALID = 'key_invalid';

    public const MODEL_NOT_FOUND = 'model_not_found';

    public const RATE_LIMITED = 'provider_rate_limited';

    public const UNAVAILABLE = 'provider_unavailable';

    public const UNREACHABLE = 'provider_unreachable';

    public const ERROR = 'provider_error';

    public function __construct(
        public readonly string $errorCode,
        string $message,
        ?Throwable $previous = null,
    ) {
        parent::__construct($message, 0, $previous);
    }

    /**
     * A 429 is only sent after the provider has accepted the key, so a key test that hits it
     * still proves the key works (free models are often throttled upstream).
     */
    public function keyWasAccepted(): bool
    {
        return $this->errorCode === self::RATE_LIMITED;
    }

    /** A short message in the request's language that the app can show as-is. */
    public function userMessage(bool $userKey): string
    {
        return match ($this->errorCode) {
            self::KEY_INVALID => $userKey
                ? __('The provider rejected your API key. Check it in My AI key.')
                : __('The AI service is having trouble. Try again later.'),
            self::MODEL_NOT_FOUND => $userKey
                ? __('The model you chose is not available at the provider.')
                : __('The AI model set by the admin is not available.'),
            self::RATE_LIMITED => __('The AI provider is limiting requests. Try again in a moment.'),
            self::UNAVAILABLE, self::UNREACHABLE => __('The AI provider cannot be reached right now. Try again later.'),
            default => __('Something went wrong at the AI provider. Try again.'),
        };
    }
}

<?php

namespace App\Llm;

/**
 * Which model to call and with whose key, decided per request.
 */
final readonly class ResolvedModel
{
    public const SOURCE_PLATFORM = 'platform';

    public const SOURCE_USER = 'user';

    public function __construct(
        public string $keySource,
        public string $providerName,
        public string $driver,
        public ?string $baseUrl,
        public string $apiKey,
        public string $modelId,
        public bool $supportsTools = true,
    ) {}

    public function isUserKey(): bool
    {
        return $this->keySource === self::SOURCE_USER;
    }
}

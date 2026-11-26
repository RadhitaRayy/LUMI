<?php

namespace App\Llm;

use App\Models\LlmProvider;

/**
 * Sends one tiny request to check that a key and model work.
 * A rate-limit answer counts as success: providers only send it after accepting the key.
 */
class KeyTester
{
    public function __construct(private readonly ChatDriver $driver) {}

    /** Null when the key works, otherwise what went wrong. */
    public function check(ResolvedModel $model): ?LlmException
    {
        try {
            $this->driver->ping($model);
        } catch (LlmException $e) {
            return $e->keyWasAccepted() ? null : $e;
        }

        return null;
    }

    /** Test a platform provider with one of its models and remember the result on the provider. */
    public function checkProvider(LlmProvider $provider, string $modelId, ?string $apiKey = null): ?LlmException
    {
        $error = $this->check(self::platformModel($provider, $modelId, $apiKey));

        if ($provider->exists) {
            $provider->forceFill([
                'last_tested_at' => now(),
                'last_error' => $error?->userMessage(false),
            ])->save();
        }

        return $error;
    }

    public static function platformModel(LlmProvider $provider, string $modelId, ?string $apiKey = null): ResolvedModel
    {
        return new ResolvedModel(
            ResolvedModel::SOURCE_PLATFORM,
            $provider->name,
            $provider->driver,
            $provider->base_url,
            (string) ($apiKey ?? $provider->api_key),
            $modelId,
        );
    }
}

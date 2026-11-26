<?php

namespace App\Llm;

use App\Exceptions\ApiException;
use App\Models\LlmModel;
use App\Models\User;

/**
 * Hybrid BYOK: the user's own active key wins, otherwise the platform default model.
 */
class ModelResolver
{
    public function for(User $user): ResolvedModel
    {
        $userKey = $user->activeAiKey();

        if ($userKey !== null) {
            return new ResolvedModel(
                keySource: ResolvedModel::SOURCE_USER,
                providerName: $userKey->driver === 'openrouter' ? 'OpenRouter' : 'Kunci pribadi',
                driver: $userKey->driver,
                baseUrl: $userKey->base_url,
                apiKey: $userKey->api_key,
                modelId: $userKey->model_id,
            );
        }

        $model = LlmModel::platformDefault();

        if ($model === null) {
            throw new ApiException('no_model_configured', 'Belum ada model AI yang diatur admin.', 503);
        }

        return new ResolvedModel(
            keySource: ResolvedModel::SOURCE_PLATFORM,
            providerName: $model->provider->name,
            driver: $model->provider->driver,
            baseUrl: $model->provider->base_url,
            apiKey: (string) $model->provider->api_key,
            modelId: $model->model_id,
        );
    }
}

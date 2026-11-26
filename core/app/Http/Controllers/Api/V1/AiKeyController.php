<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Llm\ChatDriver;
use App\Llm\LlmException;
use App\Llm\ResolvedModel;
use App\Models\UserAiKey;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * "Kunci AI saya": the user's own AI key (hybrid BYOK). The key is never returned.
 */
class AiKeyController extends Controller
{
    public function __construct(private readonly ChatDriver $driver) {}

    public function show(Request $request): JsonResponse
    {
        return response()->json(['ai_key' => $this->present($request->user()->aiKey()->first())]);
    }

    public function upsert(Request $request): JsonResponse
    {
        $data = $request->validate([
            'driver' => ['required', Rule::in(['openrouter', 'openai_compatible'])],
            'base_url' => ['nullable', 'required_if:driver,openai_compatible', 'url:https', 'max:255'],
            'api_key' => ['required', 'string', 'min:10', 'max:500'],
            'model_id' => ['required', 'string', 'max:150'],
        ]);

        $apiKey = trim($data['api_key']);
        $baseUrl = $data['driver'] === 'openrouter' ? null : rtrim((string) $data['base_url'], '/');

        $this->check(new ResolvedModel(
            keySource: ResolvedModel::SOURCE_USER,
            providerName: 'Kunci pribadi',
            driver: $data['driver'],
            baseUrl: $baseUrl,
            apiKey: $apiKey,
            modelId: $data['model_id'],
        ));

        $key = $request->user()->aiKey()->updateOrCreate([], [
            'driver' => $data['driver'],
            'base_url' => $baseUrl,
            'api_key' => $apiKey,
            'key_last4' => substr($apiKey, -4),
            'model_id' => $data['model_id'],
            'is_active' => true,
            'last_validated_at' => now(),
            'last_error' => null,
        ]);

        return response()->json(['ai_key' => $this->present($key)]);
    }

    public function test(Request $request): JsonResponse
    {
        $key = $this->ownKey($request);

        try {
            $this->check(new ResolvedModel(
                keySource: ResolvedModel::SOURCE_USER,
                providerName: 'Kunci pribadi',
                driver: $key->driver,
                baseUrl: $key->base_url,
                apiKey: $key->api_key,
                modelId: $key->model_id,
            ));
        } catch (ApiException $e) {
            $key->forceFill(['last_error' => $e->getMessage()])->save();
            throw $e;
        }

        $key->forceFill(['last_validated_at' => now(), 'last_error' => null])->save();

        return response()->json(['ai_key' => $this->present($key)]);
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate(['is_active' => ['required', 'boolean']]);

        $key = $this->ownKey($request);
        $key->update($data);

        return response()->json(['ai_key' => $this->present($key)]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $request->user()->aiKey()->delete();
        $request->user()->unsetRelation('aiKey');

        return response()->json(['message' => 'Kunci AI dihapus. Lumi kembali memakai kuota gratis.']);
    }

    private function check(ResolvedModel $model): void
    {
        try {
            $this->driver->ping($model);
        } catch (LlmException $e) {
            throw new ApiException('ai_key_invalid', $e->userMessage(true), 422, ['reason' => $e->errorCode]);
        }
    }

    private function ownKey(Request $request): UserAiKey
    {
        return $request->user()->aiKey()->first()
            ?? throw new ApiException('ai_key_missing', 'Kamu belum memasang kunci AI.', 404);
    }

    /** @return array<string, mixed>|null */
    private function present(?UserAiKey $key): ?array
    {
        if ($key === null) {
            return null;
        }

        return [
            'driver' => $key->driver,
            'base_url' => $key->base_url,
            'model_id' => $key->model_id,
            'key_last4' => $key->key_last4,
            'is_active' => $key->is_active,
            'last_validated_at' => $key->last_validated_at?->toIso8601String(),
            'last_error' => $key->last_error,
        ];
    }
}

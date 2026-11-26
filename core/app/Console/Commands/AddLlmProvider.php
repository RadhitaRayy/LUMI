<?php

namespace App\Console\Commands;

use App\Llm\ChatDriver;
use App\Llm\LlmException;
use App\Llm\ResolvedModel;
use App\Models\LlmModel;
use App\Models\LlmProvider;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Adds a platform AI provider + default model until Lumi Console has a page for it.
 * The API key is typed hidden and stored encrypted.
 */
#[Signature('lumi:add-provider
    {driver : openrouter or openai_compatible (e.g. NVIDIA NIM)}
    {model : Model id, e.g. meta-llama/llama-3.3-70b-instruct:free}
    {--name= : Display name, e.g. "OpenRouter" or "NVIDIA NIM"}
    {--url= : Base URL for openai_compatible, e.g. https://integrate.api.nvidia.com/v1}
    {--label= : Model label shown in the Console}
    {--no-test : Skip the test request to the provider}')]
#[Description('Add a platform AI provider (key typed hidden) and make its model the default')]
class AddLlmProvider extends Command
{
    public function handle(ChatDriver $driver): int
    {
        $type = (string) $this->argument('driver');
        if (! in_array($type, ['openrouter', 'openai_compatible'], true)) {
            $this->error('Driver must be openrouter or openai_compatible.');

            return self::FAILURE;
        }

        $url = $type === 'openrouter' ? null : rtrim((string) $this->option('url'), '/');
        if ($type === 'openai_compatible' && ! $url) {
            $this->error('--url is required for openai_compatible.');

            return self::FAILURE;
        }

        $apiKey = trim((string) $this->secret('API key (hidden)'));
        if ($apiKey === '') {
            $this->error('No API key given.');

            return self::FAILURE;
        }

        $name = $this->option('name') ?: ($type === 'openrouter' ? 'OpenRouter' : 'OpenAI-compatible');
        $modelId = (string) $this->argument('model');

        if (! $this->option('no-test')) {
            $this->line('Testing the key with a tiny request...');
            try {
                $driver->ping(new ResolvedModel(ResolvedModel::SOURCE_PLATFORM, $name, $type, $url, $apiKey, $modelId));
            } catch (LlmException $e) {
                $this->error("Provider refused the test ({$e->errorCode}): {$e->getMessage()}");

                return self::FAILURE;
            }
            $this->info('Key works.');
        }

        DB::transaction(function () use ($name, $type, $url, $apiKey, $modelId) {
            $provider = LlmProvider::create([
                'name' => $name,
                'driver' => $type,
                'base_url' => $url,
                'api_key' => $apiKey,
                'is_enabled' => true,
            ]);

            LlmModel::query()->update(['is_default' => false]);

            $provider->models()->create([
                'model_id' => $modelId,
                'label' => $this->option('label') ?: $modelId,
                'is_default' => true,
                'is_enabled' => true,
            ]);
        });

        $this->info("{$name} added; {$modelId} is now the default model.");

        return self::SUCCESS;
    }
}

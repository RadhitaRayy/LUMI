<?php

namespace App\Http\Controllers\Console;

use App\Http\Controllers\Controller;
use App\Llm\KeyTester;
use App\Models\LlmModel;
use App\Models\LlmProvider;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;

/** Platform AI providers (the owner's keys) and their models. Keys are never sent to the browser. */
class ProviderController extends Controller
{
    public function __construct(private readonly KeyTester $tester) {}

    public function index(): Response
    {
        $default = LlmModel::platformDefault();

        return Inertia::render('console/providers', [
            'providers' => LlmProvider::with(['models' => fn ($q) => $q->oldest('id')])->oldest('id')->get()
                ->map(fn (LlmProvider $p) => [
                    'id' => $p->id,
                    'name' => $p->name,
                    'driver' => $p->driver,
                    'base_url' => $p->base_url,
                    'key_last4' => $p->keyLast4(),
                    'is_enabled' => $p->is_enabled,
                    'last_tested_at' => $p->last_tested_at?->toIso8601String(),
                    'last_error' => $p->last_error,
                    'models' => $p->models->map(fn (LlmModel $m) => [
                        'id' => $m->id,
                        'model_id' => $m->model_id,
                        'label' => $m->label,
                        'is_enabled' => $m->is_enabled,
                        'is_default' => $default?->id === $m->id,
                    ]),
                ]),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'driver' => ['required', Rule::in(['openrouter', 'openai_compatible'])],
            'base_url' => ['nullable', 'required_if:driver,openai_compatible', 'url:https', 'max:255'],
            'api_key' => ['required', 'string', 'min:10', 'max:500'],
            'model_id' => ['required', 'string', 'max:150'],
            'label' => ['nullable', 'string', 'max:80'],
        ]);

        $provider = new LlmProvider([
            'name' => $data['name'],
            'driver' => $data['driver'],
            'base_url' => $data['driver'] === 'openrouter' ? null : rtrim((string) $data['base_url'], '/'),
            'api_key' => trim($data['api_key']),
            'is_enabled' => true,
        ]);

        $this->ensureWorks($provider, $data['model_id'], 'api_key');

        DB::transaction(function () use ($provider, $data) {
            $provider->forceFill(['last_tested_at' => now(), 'last_error' => null])->save();
            $provider->models()->create([
                'model_id' => $data['model_id'],
                'label' => ($data['label'] ?? null) ?: $data['model_id'],
                'is_default' => ! LlmModel::where('is_default', true)->exists(),
                'is_enabled' => true,
            ]);
        });

        Inertia::flash('toast', ['type' => 'success', 'message' => "{$provider->name} tersambung dan disimpan."]);

        return back();
    }

    public function updateKey(Request $request, LlmProvider $provider): RedirectResponse
    {
        $data = $request->validate(['api_key' => ['required', 'string', 'min:10', 'max:500']]);
        $key = trim($data['api_key']);

        $this->ensureWorks($provider, $this->testModel($provider), 'api_key', $key);
        $provider->forceFill(['api_key' => $key])->save();

        Inertia::flash('toast', ['type' => 'success', 'message' => "Key {$provider->name} diganti."]);

        return back();
    }

    public function test(LlmProvider $provider): RedirectResponse
    {
        $error = $this->tester->checkProvider($provider, $this->testModel($provider));

        Inertia::flash('toast', $error === null
            ? ['type' => 'success', 'message' => "{$provider->name} tersambung."]
            : ['type' => 'error', 'message' => "{$provider->name}: {$error->userMessage(false)}"]);

        return back();
    }

    public function update(Request $request, LlmProvider $provider): RedirectResponse
    {
        $data = $request->validate(['is_enabled' => ['required', 'boolean']]);
        $provider->update($data);

        Inertia::flash('toast', [
            'type' => 'success',
            'message' => $provider->is_enabled ? "{$provider->name} diaktifkan." : "{$provider->name} dinonaktifkan.",
        ]);

        return back();
    }

    public function destroy(LlmProvider $provider): RedirectResponse
    {
        $provider->delete();
        Inertia::flash('toast', ['type' => 'success', 'message' => "{$provider->name} dihapus."]);

        return back();
    }

    /** The model used for connection tests: the provider's default, else its first. */
    private function testModel(LlmProvider $provider): string
    {
        $model = $provider->models()->orderByDesc('is_default')->oldest('id')->value('model_id');

        if ($model === null) {
            throw ValidationException::withMessages(['provider' => 'Tambahkan model dulu sebelum menguji provider ini.']);
        }

        return $model;
    }

    private function ensureWorks(LlmProvider $provider, string $modelId, string $field, ?string $key = null): void
    {
        $error = $this->tester->checkProvider($provider, $modelId, $key);

        if ($error !== null) {
            throw ValidationException::withMessages([$field => "Provider menolak tes ({$error->errorCode}): {$error->userMessage(false)}"]);
        }
    }
}

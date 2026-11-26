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

class ModelController extends Controller
{
    public function __construct(private readonly KeyTester $tester) {}

    public function store(Request $request, LlmProvider $provider): RedirectResponse
    {
        $data = $request->validate([
            'model_id' => ['required', 'string', 'max:150', Rule::unique('llm_models')->where('llm_provider_id', $provider->id)],
            'label' => ['nullable', 'string', 'max:80'],
        ]);

        $error = $this->tester->checkProvider($provider, $data['model_id']);
        if ($error !== null) {
            throw ValidationException::withMessages(['model_id' => "Model ditolak ({$error->errorCode}): {$error->userMessage(false)}"]);
        }

        $provider->models()->create([
            'model_id' => $data['model_id'],
            'label' => ($data['label'] ?? null) ?: $data['model_id'],
            'is_default' => false,
            'is_enabled' => true,
        ]);

        Inertia::flash('toast', ['type' => 'success', 'message' => 'Model ditambahkan.']);

        return back();
    }

    public function update(Request $request, LlmModel $model): RedirectResponse
    {
        $data = $request->validate(['is_enabled' => ['required', 'boolean']]);

        if (! $data['is_enabled'] && $model->is_default) {
            return back()->withErrors(['model' => 'Model default tidak bisa dinonaktifkan. Pilih default lain dulu.']);
        }

        $model->update($data);

        return back();
    }

    public function makeDefault(LlmModel $model): RedirectResponse
    {
        DB::transaction(function () use ($model) {
            LlmModel::query()->update(['is_default' => false]);
            $model->forceFill(['is_default' => true, 'is_enabled' => true])->save();
        });

        Inertia::flash('toast', ['type' => 'success', 'message' => "{$model->label} jadi model default."]);

        return back();
    }

    public function destroy(LlmModel $model): RedirectResponse
    {
        if ($model->is_default) {
            return back()->withErrors(['model' => 'Model default tidak bisa dihapus. Pilih default lain dulu.']);
        }

        $model->delete();
        Inertia::flash('toast', ['type' => 'success', 'message' => "{$model->label} dihapus."]);

        return back();
    }
}

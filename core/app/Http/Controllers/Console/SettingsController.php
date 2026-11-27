<?php

namespace App\Http\Controllers\Console;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Services\Agent\PromptAssembler;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class SettingsController extends Controller
{
    public function edit(PromptAssembler $prompts): Response
    {
        $settings = AppSetting::current();

        return Inertia::render('console/settings', [
            'settings' => [
                'registration_open' => $settings->registration_open,
                'require_email_verification' => $settings->require_email_verification,
                'default_daily_quota' => $settings->default_daily_quota,
                'system_prompt' => $settings->system_prompt,
                'updated_at' => $settings->updated_at?->toIso8601String(),
            ],
            'promptLayers' => [
                'core' => $prompts->corePrompt(),
                'orchestrator' => $prompts->orchestratorPrompt(),
            ],
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'registration_open' => ['required', 'boolean'],
            'require_email_verification' => ['required', 'boolean'],
            'default_daily_quota' => ['required', 'integer', 'min:0', 'max:100000'],
            'system_prompt' => ['required', 'string', 'max:4000'],
        ]);

        AppSetting::current()->update($data);
        Inertia::flash('toast', ['type' => 'success', 'message' => 'Pengaturan disimpan.']);

        return back();
    }
}

<?php

namespace App\Http\Controllers\Console;

use App\Enums\Role;
use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\ToolPolicy;
use App\Services\Agent\ToolRegistry;
use App\Services\Agent\Tools\WebSearchTool;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;

/** Manages per-role agent tool permissions and optional Web Search credentials. */
class ToolController extends Controller
{
    public function index(ToolRegistry $registry): Response
    {
        $settings = AppSetting::current();
        $savedKey = is_string($settings->web_search_api_key) ? trim($settings->web_search_api_key) : '';

        $policies = ToolPolicy::query()->get()->keyBy(fn (ToolPolicy $p): string => "{$p->tool_name}:{$p->role}");

        $tools = [];
        foreach ($registry->all() as $tool) {
            $name = $tool->name();
            $userPolicy = $policies->get("{$name}:".Role::User->value);
            $adminPolicy = $policies->get("{$name}:".Role::Superadmin->value);

            $userMode = $userPolicy !== null
                ? ($userPolicy->is_enabled ? $userPolicy->mode : ToolPolicy::MODE_DISABLED)
                : $tool->defaultMode(Role::User);
            $adminMode = $adminPolicy !== null
                ? ($adminPolicy->is_enabled ? $adminPolicy->mode : ToolPolicy::MODE_DISABLED)
                : $tool->defaultMode(Role::Superadmin);

            $tools[] = [
                'name' => $name,
                'label' => $tool->label(),
                'description' => $tool->description(),
                'available' => $tool->isAvailable(),
                'user_mode' => $userMode,
                'superadmin_mode' => $adminMode,
                'default_user_mode' => $tool->defaultMode(Role::User),
                'default_superadmin_mode' => $tool->defaultMode(Role::Superadmin),
            ];
        }

        return Inertia::render('console/tools', [
            'tools' => $tools,
            'webSearch' => [
                'enabled' => $settings->web_search_enabled,
                'driver' => $settings->web_search_driver ?: 'tavily',
                'has_key' => $savedKey !== '',
                'key_last4' => $savedKey !== '' ? substr($savedKey, -4) : null,
            ],
        ]);
    }

    public function updatePolicy(Request $request, string $tool, ToolRegistry $registry): RedirectResponse
    {
        abort_if($registry->find($tool) === null, 404);

        $data = $request->validate([
            'user_mode' => ['required', 'string', Rule::in(ToolPolicy::MODES)],
            'superadmin_mode' => ['required', 'string', Rule::in(ToolPolicy::MODES)],
        ]);

        foreach ([
            Role::User->value => $data['user_mode'],
            Role::Superadmin->value => $data['superadmin_mode'],
        ] as $role => $mode) {
            ToolPolicy::query()->updateOrCreate(
                ['tool_name' => $tool, 'role' => $role],
                [
                    'mode' => $mode,
                    'is_enabled' => $mode !== ToolPolicy::MODE_DISABLED,
                ],
            );
        }

        Inertia::flash('toast', ['type' => 'success', 'message' => "Izin tool {$tool} disimpan."]);

        return back();
    }

    public function updateWebSearch(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'enabled' => ['required', 'boolean'],
            'driver' => ['required', 'string', Rule::in(['tavily', 'brave'])],
            'api_key' => ['nullable', 'string', 'max:300'],
            'clear_key' => ['sometimes', 'boolean'],
        ]);

        $settings = AppSetting::current();
        $clearKey = (bool) ($data['clear_key'] ?? false);
        $incomingKey = is_string($data['api_key'] ?? null) ? trim($data['api_key']) : '';
        $existingKey = is_string($settings->web_search_api_key) ? trim($settings->web_search_api_key) : '';

        $nextKey = $clearKey ? null : ($incomingKey !== '' ? $incomingKey : ($existingKey !== '' ? $existingKey : null));
        $enabled = $clearKey ? false : (bool) $data['enabled'];

        if ($enabled && $nextKey === null) {
            return back()->withErrors([
                'api_key' => 'Masukkan API key terlebih dahulu untuk mengaktifkan Web Search.',
            ]);
        }

        $settings->update([
            'web_search_driver' => $data['driver'],
            'web_search_api_key' => $nextKey,
            'web_search_enabled' => $enabled,
        ]);

        Inertia::flash('toast', ['type' => 'success', 'message' => 'Pengaturan Web Search disimpan.']);

        return back();
    }

    public function testWebSearch(Request $request, WebSearchTool $webSearch): RedirectResponse
    {
        $data = $request->validate([
            'driver' => ['nullable', 'string', Rule::in(['tavily', 'brave'])],
            'api_key' => ['nullable', 'string', 'max:300'],
        ]);

        $settings = AppSetting::current();
        $driver = $data['driver'] ?? ($settings->web_search_driver ?: 'tavily');
        $incomingKey = is_string($data['api_key'] ?? null) ? trim($data['api_key']) : '';
        $apiKey = $incomingKey !== '' ? $incomingKey : trim((string) $settings->web_search_api_key);

        $result = $webSearch->testConnection($driver, $apiKey);

        Inertia::flash('toast', [
            'type' => $result['ok'] ? 'success' : 'error',
            'message' => $result['message'],
        ]);

        return back();
    }
}

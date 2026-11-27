<?php

use App\Enums\Role;
use App\Models\AppSetting;
use App\Models\AuditLog;
use App\Models\ToolPolicy;
use App\Models\User;
use App\Services\Agent\ToolRegistry;
use Illuminate\Support\Facades\Http;
use Inertia\Testing\AssertableInertia as Assert;

describe('console tools & audit', function () {
    it('blocks non-superadmin users from console tools and audit pages', function () {
        $user = User::factory()->create(['role' => Role::User]);

        $this->actingAs($user)->get('/console/tools')->assertRedirect('/login');
        $this->actingAs($user)->get('/console/audit')->assertRedirect('/login');
        $this->actingAs($user)->put('/console/tools/save_note', [
            'user_mode' => 'disabled',
            'superadmin_mode' => 'auto',
        ])->assertRedirect('/login');
        $this->actingAs($user)->put('/console/tools/web-search', [
            'enabled' => false,
            'driver' => 'tavily',
        ])->assertRedirect('/login');
    });

    it('renders registered tools and updates per-role tool policies cleanly', function () {
        $admin = User::factory()->create(['role' => Role::Superadmin]);

        $this->actingAs($admin)
            ->get('/console/tools')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('console/tools')
                ->has('tools', 7)
                ->where('webSearch.enabled', false)
                ->where('webSearch.has_key', false)
            );

        $this->actingAs($admin)
            ->put('/console/tools/save_note', [
                'user_mode' => ToolPolicy::MODE_ASK,
                'superadmin_mode' => ToolPolicy::MODE_AUTO,
            ])
            ->assertRedirect();

        $registry = app(ToolRegistry::class);
        expect($registry->resolveMode('save_note', Role::User))->toBe(ToolPolicy::MODE_ASK)
            ->and($registry->resolveMode('save_note', Role::Superadmin))->toBe(ToolPolicy::MODE_AUTO);

        // Disabling sets is_enabled = false and disables the tool for that role.
        $this->actingAs($admin)
            ->put('/console/tools/save_note', [
                'user_mode' => ToolPolicy::MODE_DISABLED,
                'superadmin_mode' => ToolPolicy::MODE_ASK,
            ])
            ->assertRedirect();

        expect($registry->resolveMode('save_note', Role::User))->toBe(ToolPolicy::MODE_DISABLED)
            ->and($registry->resolveMode('save_note', Role::Superadmin))->toBe(ToolPolicy::MODE_ASK);
    });

    it('saves encrypted web search key, masks it in props, tests connection, and clears key', function () {
        $admin = User::factory()->create(['role' => Role::Superadmin]);

        // Enabling without a key fails validation.
        $this->actingAs($admin)
            ->put('/console/tools/web-search', [
                'enabled' => true,
                'driver' => 'tavily',
                'api_key' => '',
            ])
            ->assertSessionHasErrors('api_key');

        // Saving a valid key enables Web Search and exposes only last 4 chars.
        $this->actingAs($admin)
            ->put('/console/tools/web-search', [
                'enabled' => true,
                'driver' => 'tavily',
                'api_key' => 'tvly-secret-test-9876',
            ])
            ->assertRedirect();

        $settings = AppSetting::current()->refresh();
        expect($settings->web_search_enabled)->toBeTrue()
            ->and($settings->web_search_driver)->toBe('tavily')
            ->and($settings->web_search_api_key)->toBe('tvly-secret-test-9876');

        $this->actingAs($admin)
            ->get('/console/tools')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->where('webSearch.enabled', true)
                ->where('webSearch.has_key', true)
                ->where('webSearch.key_last4', '9876')
                ->missing('webSearch.api_key')
            );

        // Connection test hits Tavily API and succeeds.
        Http::fake([
            'https://api.tavily.com/search' => Http::response(['results' => []], 200),
        ]);

        $this->actingAs($admin)
            ->post('/console/tools/web-search/test')
            ->assertRedirect();

        // Clearing key disables Web Search and wipes the stored key.
        $this->actingAs($admin)
            ->put('/console/tools/web-search', [
                'enabled' => false,
                'driver' => 'tavily',
                'clear_key' => true,
            ])
            ->assertRedirect();

        $settings->refresh();
        expect($settings->web_search_enabled)->toBeFalse()
            ->and($settings->web_search_api_key)->toBeNull();
    });

    it('lists and filters audit logs by user, tool, status, and date', function () {
        $admin = User::factory()->create(['role' => Role::Superadmin, 'name' => 'Admin']);
        $alice = User::factory()->create(['role' => Role::User, 'name' => 'Alice']);

        AuditLog::create([
            'user_id' => $alice->id,
            'tool_name' => 'delete_note',
            'mode' => ToolPolicy::MODE_ASK,
            'status' => AuditLog::STATUS_APPROVED,
            'summary' => 'Deleted note "Draft"',
            'latency_ms' => 15,
            'created_at' => now()->subHour(),
        ]);

        AuditLog::create([
            'user_id' => $admin->id,
            'tool_name' => 'get_time',
            'mode' => ToolPolicy::MODE_AUTO,
            'status' => AuditLog::STATUS_EXECUTED,
            'summary' => 'Asia/Jakarta',
            'latency_ms' => 2,
            'created_at' => now()->subDays(2),
        ]);

        $this->actingAs($admin)
            ->get('/console/audit')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('console/audit')
                ->has('logs.data', 2)
            );

        $this->actingAs($admin)
            ->get("/console/audit?user={$alice->id}&tool=delete_note&status=approved")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->has('logs.data', 1)
                ->where('logs.data.0.tool_name', 'delete_note')
                ->where('logs.data.0.status', 'approved')
                ->where('logs.data.0.user', 'Alice')
            );
    });
});

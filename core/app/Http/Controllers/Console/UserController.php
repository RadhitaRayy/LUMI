<?php

namespace App\Http\Controllers\Console;

use App\Events\SessionRevoked;
use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;
use Laravel\Sanctum\PersonalAccessToken;

class UserController extends Controller
{
    private const FILTERS = ['all', 'unverified', 'blocked', 'own_key'];

    public function index(Request $request): Response
    {
        $q = trim((string) $request->query('q', ''));
        $filter = in_array($request->query('filter'), self::FILTERS, true) ? (string) $request->query('filter') : 'all';

        $users = $this->filtered(User::query(), $filter)
            ->when($q !== '', fn (Builder $query) => $query->where(fn (Builder $w) => $w
                ->where('name', 'ilike', "%{$q}%")
                ->orWhere('email', 'ilike', "%{$q}%")))
            ->withCount('tokens')
            ->with('aiKey')
            ->orderByRaw("role = 'superadmin' desc")
            ->oldest('id')
            ->paginate(20)
            ->withQueryString();

        $selectedId = (int) $request->query('user', 0) ?: $users->first()?->id;
        $selected = $selectedId ? User::with('aiKey')->find($selectedId) : null;

        return Inertia::render('console/users', [
            'filters' => ['q' => $q, 'filter' => $filter],
            'counts' => collect(self::FILTERS)->mapWithKeys(fn (string $f) => [$f => $this->filtered(User::query(), $f)->count()]),
            'registrationOpen' => AppSetting::current()->registration_open,
            'users' => $users->through(fn (User $u) => $this->row($u)),
            'selected' => $selected ? $this->detail($selected, $request->user()) : null,
        ]);
    }

    public function updateQuota(Request $request, User $user): RedirectResponse
    {
        $data = $request->validate([
            'daily_quota' => ['nullable', 'integer', 'min:0', 'max:100000'],
        ]);

        $user->forceFill(['daily_quota' => $data['daily_quota']])->save();
        Inertia::flash('toast', ['type' => 'success', 'message' => "Kuota {$user->name} disimpan."]);

        return back();
    }

    public function block(Request $request, User $user): RedirectResponse
    {
        if ($user->isSuperadmin()) {
            return back()->withErrors(['block' => 'Superadmin tidak bisa diblokir.']);
        }

        $tokenIds = $user->tokens()->pluck('id')->all();
        $user->forceFill(['is_blocked' => true])->save();
        $user->tokens()->delete();
        if ($tokenIds !== []) {
            broadcast(SessionRevoked::for($user->id, $tokenIds));
        }

        Inertia::flash('toast', ['type' => 'success', 'message' => "{$user->name} diblokir dan dikeluarkan dari semua perangkat."]);

        return back();
    }

    public function unblock(User $user): RedirectResponse
    {
        $user->forceFill(['is_blocked' => false])->save();
        Inertia::flash('toast', ['type' => 'success', 'message' => "Blokir {$user->name} dibuka."]);

        return back();
    }

    public function revokeDevice(User $user, int $token): RedirectResponse
    {
        /** @var PersonalAccessToken $device */
        $device = $user->tokens()->findOrFail($token);
        $device->delete();
        broadcast(SessionRevoked::for($user->id, [$device->getKey()]));

        Inertia::flash('toast', ['type' => 'success', 'message' => "{$device->name} dikeluarkan."]);

        return back();
    }

    /**
     * @param  Builder<User>  $query
     * @return Builder<User>
     */
    private function filtered(Builder $query, string $filter): Builder
    {
        return match ($filter) {
            'unverified' => $query->whereNull('email_verified_at'),
            'blocked' => $query->where('is_blocked', true),
            'own_key' => $query->whereHas('aiKey', fn (Builder $k) => $k->where('is_active', true)),
            default => $query,
        };
    }

    /** @return array<string, mixed> */
    private function row(User $user): array
    {
        $ownKey = $user->aiKey !== null && $user->aiKey->is_active;

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role->value,
            'is_blocked' => $user->is_blocked,
            'email_verified' => $user->email_verified_at !== null,
            'own_key' => $ownKey,
            'quota_used' => $ownKey ? null : $user->platformMessagesToday(),
            'quota_limit' => $user->effectiveDailyQuota(),
            'devices' => (int) $user->getAttribute('tokens_count'),
        ];
    }

    /** @return array<string, mixed> */
    private function detail(User $user, User $viewer): array
    {
        $key = $user->aiKey;

        return [
            ...$this->row($user->loadCount('tokens')),
            'joined' => $user->created_at?->toIso8601String(),
            'daily_quota' => $user->daily_quota,
            'can_block' => ! $user->isSuperadmin() && $user->id !== $viewer->id,
            'ai_key' => $key ? [
                'driver' => $key->driver,
                'base_url' => $key->base_url,
                'model_id' => $key->model_id,
                'key_last4' => $key->key_last4,
                'is_active' => $key->is_active,
                'last_validated_at' => $key->last_validated_at?->toIso8601String(),
                'last_error' => $key->last_error,
            ] : null,
            'device_list' => $user->tokens()->latest('last_used_at')->get(['id', 'name', 'last_used_at', 'created_at'])
                ->map(fn (PersonalAccessToken $t) => [
                    'id' => $t->id,
                    'name' => $t->name,
                    'last_used_at' => $t->last_used_at?->toIso8601String(),
                    'created_at' => $t->created_at?->toIso8601String(),
                ]),
        ];
    }
}

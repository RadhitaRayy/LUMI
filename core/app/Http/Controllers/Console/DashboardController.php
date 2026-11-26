<?php

namespace App\Http\Controllers\Console;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\LlmModel;
use App\Models\LlmUsage;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class DashboardController extends Controller
{
    private const DAYS = 14;

    public function __invoke(): Response
    {
        $tz = 'Asia/Jakarta';
        $todayStart = now($tz)->startOfDay()->utc();

        $today = LlmUsage::query()->where('created_at', '>=', $todayStart);
        $default = LlmModel::platformDefault();

        return Inertia::render('console/dashboard', [
            'today' => now($tz)->toDateString(),
            'stats' => [
                'users' => User::count(),
                'unverified' => User::whereNull('email_verified_at')->count(),
                'blocked' => User::where('is_blocked', true)->count(),
                'messages' => (clone $today)->where('status', '!=', 'error')->count(),
                'messages_platform' => (clone $today)->where('status', '!=', 'error')->where('key_source', 'platform')->count(),
                'messages_user' => (clone $today)->where('status', '!=', 'error')->where('key_source', 'user')->count(),
                'input_tokens' => (int) (clone $today)->sum('input_tokens'),
                'output_tokens' => (int) (clone $today)->sum('output_tokens'),
                'errors' => (clone $today)->where('status', 'error')->count(),
                'top_error' => (clone $today)->where('status', 'error')
                    ->select('error_code', DB::raw('count(*) as total'))
                    ->groupBy('error_code')->orderByDesc('total')->value('error_code'),
            ],
            'series' => $this->series($tz),
            'defaultModel' => $default ? [
                'label' => $default->label,
                'model_id' => $default->model_id,
                'provider' => $default->provider->name,
                'key_last4' => $default->provider->keyLast4(),
                'last_tested_at' => $default->provider->last_tested_at?->toIso8601String(),
                'last_error' => $default->provider->last_error,
            ] : null,
            'defaultQuota' => AppSetting::current()->default_daily_quota,
            'recentErrors' => LlmUsage::query()
                ->with('user:id,name')
                ->where('status', 'error')
                ->latest('id')
                ->limit(5)
                ->get()
                ->map(fn (LlmUsage $u) => [
                    'id' => $u->id,
                    'at' => $u->created_at?->toIso8601String(),
                    'user' => $u->user?->name,
                    'model' => $u->model,
                    'error_code' => $u->error_code,
                    'key_source' => $u->key_source,
                ]),
        ]);
    }

    /**
     * Answers and tokens per day (WIB) for the last 14 days, oldest first, empty days included.
     *
     * @return list<array{date: string, messages: int, tokens: int}>
     */
    private function series(string $tz): array
    {
        $from = now($tz)->startOfDay()->subDays(self::DAYS - 1);

        $rows = LlmUsage::query()
            ->where('created_at', '>=', $from->copy()->utc())
            ->where('status', '!=', 'error')
            ->get(['created_at', 'input_tokens', 'output_tokens'])
            ->groupBy(fn (LlmUsage $u) => Carbon::parse($u->created_at)->setTimezone($tz)->toDateString());

        $series = [];
        for ($i = 0; $i < self::DAYS; $i++) {
            $date = $from->copy()->addDays($i)->toDateString();
            $day = $rows->get($date, collect());
            $series[] = [
                'date' => $date,
                'messages' => $day->count(),
                'tokens' => (int) $day->sum(fn (LlmUsage $u) => $u->input_tokens + $u->output_tokens),
            ];
        }

        return $series;
    }
}

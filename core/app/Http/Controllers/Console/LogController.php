<?php

namespace App\Http\Controllers\Console;

use App\Http\Controllers\Controller;
use App\Models\LlmUsage;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Inertia\Inertia;
use Inertia\Response;

/** One row per AI answer. Conversation text is never shown here. */
class LogController extends Controller
{
    public function index(Request $request): Response
    {
        $filters = $request->validate([
            'user' => ['nullable', 'integer'],
            'model' => ['nullable', 'string', 'max:150'],
            'status' => ['nullable', 'in:complete,error,cancelled'],
            'date' => ['nullable', 'date_format:Y-m-d'],
        ]);

        $logs = LlmUsage::query()
            ->with('user:id,name')
            ->when($filters['user'] ?? null, fn (Builder $q, $id) => $q->where('user_id', $id))
            ->when($filters['model'] ?? null, fn (Builder $q, $m) => $q->where('model', $m))
            ->when($filters['status'] ?? null, fn (Builder $q, $s) => $q->where('status', $s))
            ->when($filters['date'] ?? null, function (Builder $q, $date) {
                $start = Carbon::parse($date, 'Asia/Jakarta')->startOfDay();
                $q->whereBetween('created_at', [$start->copy()->utc(), $start->copy()->endOfDay()->utc()]);
            })
            ->latest('id')
            ->paginate(25)
            ->withQueryString()
            ->through(fn (LlmUsage $u) => [
                'id' => $u->id,
                'at' => $u->created_at?->toIso8601String(),
                'user' => $u->user?->name,
                'model' => $u->model,
                'provider' => $u->provider,
                'key_source' => $u->key_source,
                'input_tokens' => $u->input_tokens,
                'output_tokens' => $u->output_tokens,
                'latency_ms' => $u->latency_ms,
                'status' => $u->status,
                'error_code' => $u->error_code,
            ]);

        return Inertia::render('console/logs', [
            'filters' => [
                'user' => isset($filters['user']) ? (string) $filters['user'] : '',
                'model' => $filters['model'] ?? '',
                'status' => $filters['status'] ?? '',
                'date' => $filters['date'] ?? '',
            ],
            'logs' => $logs,
            'users' => User::orderBy('name')->get(['id', 'name']),
            'models' => LlmUsage::query()->distinct()->orderBy('model')->pluck('model'),
        ]);
    }
}

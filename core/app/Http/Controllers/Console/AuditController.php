<?php

namespace App\Http\Controllers\Console;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\User;
use App\Services\Agent\ToolRegistry;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;

/** Filterable audit log of agent tool executions and approval decisions. Never displays chat text or keys. */
class AuditController extends Controller
{
    /** @var list<string> */
    private const STATUSES = [
        AuditLog::STATUS_EXECUTED,
        AuditLog::STATUS_APPROVED,
        AuditLog::STATUS_REJECTED,
        AuditLog::STATUS_EXPIRED,
        AuditLog::STATUS_DENIED,
        AuditLog::STATUS_ERROR,
    ];

    public function index(Request $request, ToolRegistry $registry): Response
    {
        $filters = $request->validate([
            'user' => ['nullable', 'integer'],
            'tool' => ['nullable', 'string', 'max:80'],
            'status' => ['nullable', 'string', Rule::in(self::STATUSES)],
            'date' => ['nullable', 'date_format:Y-m-d'],
        ]);

        $logs = AuditLog::query()
            ->with('user:id,name')
            ->when($filters['user'] ?? null, fn (Builder $q, $id) => $q->where('user_id', $id))
            ->when($filters['tool'] ?? null, fn (Builder $q, $tool) => $q->where('tool_name', $tool))
            ->when($filters['status'] ?? null, fn (Builder $q, $status) => $q->where('status', $status))
            ->when($filters['date'] ?? null, function (Builder $q, $date): void {
                $start = Carbon::parse($date, 'Asia/Jakarta')->startOfDay();
                $q->whereBetween('created_at', [$start->copy()->utc(), $start->copy()->endOfDay()->utc()]);
            })
            ->latest('created_at')
            ->latest('id')
            ->paginate(25)
            ->withQueryString()
            ->through(fn (AuditLog $entry): array => [
                'id' => $entry->id,
                'at' => $entry->created_at?->toIso8601String(),
                'user' => $entry->user?->name,
                'tool_name' => $entry->tool_name,
                'mode' => $entry->mode,
                'status' => $entry->status,
                'summary' => $entry->summary,
                'latency_ms' => $entry->latency_ms,
            ]);

        $registeredTools = array_map(fn ($t): string => $t->name(), $registry->all());
        $loggedTools = AuditLog::query()->distinct()->pluck('tool_name')->all();
        $tools = array_values(array_unique([...$registeredTools, ...$loggedTools]));
        sort($tools);

        return Inertia::render('console/audit', [
            'filters' => [
                'user' => isset($filters['user']) ? (string) $filters['user'] : '',
                'tool' => $filters['tool'] ?? '',
                'status' => $filters['status'] ?? '',
                'date' => $filters['date'] ?? '',
            ],
            'logs' => $logs,
            'users' => User::orderBy('name')->get(['id', 'name']),
            'tools' => $tools,
        ]);
    }
}

import { Head, router } from '@inertiajs/react';
import type { Paginated } from '@/components/console/table';
import { Pagination, Th, UsageStatus } from '@/components/console/table';
import { Label } from '@/components/ui/label';
import { latency, number, shortTime } from '@/lib/format';
import { index as logsIndex } from '@/routes/console/logs';

type Log = {
    id: number;
    at: string | null;
    user: string | null;
    model: string;
    provider: string;
    key_source: 'platform' | 'user';
    input_tokens: number;
    output_tokens: number;
    latency_ms: number;
    status: string;
    error_code: string | null;
};

type Filters = { user: string; model: string; status: string; date: string };

type Props = {
    filters: Filters;
    logs: Paginated<Log>;
    users: { id: number; name: string }[];
    models: string[];
};

const selectClass =
    'h-[42px] rounded-[10px] border border-input bg-card px-3 text-sm';

export default function Logs({ filters, logs, users, models }: Props) {
    const apply = (changes: Partial<Filters>) => {
        const next = { ...filters, ...changes };
        const query = Object.fromEntries(
            Object.entries(next).filter(([, v]) => v !== ''),
        );
        router.get(
            logsIndex.url({ query }),
            {},
            { preserveState: true, preserveScroll: true },
        );
    };

    return (
        <>
            <Head title="Log pemakaian" />
            <div className="flex flex-col gap-5 p-4 md:p-8">
                <header className="flex flex-col gap-1.5">
                    <h1 className="font-display text-[28px] font-semibold">
                        Log pemakaian
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Satu baris per jawaban AI. Isi percakapan tidak
                        ditampilkan di sini.
                    </p>
                </header>

                <form
                    aria-label="Saring log"
                    onSubmit={(e) => e.preventDefault()}
                    className="grid items-end gap-3 sm:grid-cols-2 xl:grid-cols-4"
                >
                    <div className="flex flex-col gap-1.5">
                        <Label
                            htmlFor="f-user"
                            className="text-xs text-muted-foreground"
                        >
                            User
                        </Label>
                        <select
                            id="f-user"
                            value={filters.user}
                            onChange={(e) => apply({ user: e.target.value })}
                            className={selectClass}
                        >
                            <option value="">Semua user</option>
                            {users.map((u) => (
                                <option key={u.id} value={String(u.id)}>
                                    {u.name}
                                </option>
                            ))}
                        </select>
                    </div>
                    <div className="flex flex-col gap-1.5">
                        <Label
                            htmlFor="f-model"
                            className="text-xs text-muted-foreground"
                        >
                            Model
                        </Label>
                        <select
                            id="f-model"
                            value={filters.model}
                            onChange={(e) => apply({ model: e.target.value })}
                            className={selectClass}
                        >
                            <option value="">Semua model</option>
                            {models.map((m) => (
                                <option key={m} value={m}>
                                    {m}
                                </option>
                            ))}
                        </select>
                    </div>
                    <div className="flex flex-col gap-1.5">
                        <Label
                            htmlFor="f-status"
                            className="text-xs text-muted-foreground"
                        >
                            Status
                        </Label>
                        <select
                            id="f-status"
                            value={filters.status}
                            onChange={(e) => apply({ status: e.target.value })}
                            className={selectClass}
                        >
                            <option value="">Semua status</option>
                            <option value="complete">Selesai</option>
                            <option value="error">Error</option>
                            <option value="cancelled">Dibatalkan</option>
                        </select>
                    </div>
                    <div className="flex flex-col gap-1.5">
                        <Label
                            htmlFor="f-date"
                            className="text-xs text-muted-foreground"
                        >
                            Tanggal
                        </Label>
                        <input
                            id="f-date"
                            type="date"
                            value={filters.date}
                            onChange={(e) => apply({ date: e.target.value })}
                            className={selectClass}
                        />
                    </div>
                </form>

                <section
                    aria-label="Daftar log"
                    className="overflow-hidden rounded-2xl border bg-card"
                >
                    <div className="overflow-x-auto">
                        <table className="w-full min-w-[880px] border-collapse text-[13px]">
                            <thead>
                                <tr className="text-left text-muted-foreground">
                                    <Th className="px-4">Waktu</Th>
                                    <Th className="px-4">User</Th>
                                    <Th className="px-4">Model</Th>
                                    <Th className="px-4">Key</Th>
                                    <Th className="px-4 text-right">
                                        Token masuk / keluar
                                    </Th>
                                    <Th className="px-4 text-right">Latensi</Th>
                                    <Th className="px-4">Status</Th>
                                </tr>
                            </thead>
                            <tbody>
                                {logs.data.map((l) => (
                                    <tr
                                        key={l.id}
                                        className="border-b border-border/70"
                                    >
                                        <td className="px-4 py-3 font-mono text-muted-foreground">
                                            {shortTime(l.at)}
                                        </td>
                                        <td className="px-4 py-3">
                                            {l.user ?? '–'}
                                        </td>
                                        <td
                                            className="max-w-[260px] truncate px-4 py-3 font-mono"
                                            title={l.model}
                                        >
                                            {l.model}
                                        </td>
                                        <td
                                            className={
                                                l.key_source === 'user'
                                                    ? 'px-4 py-3 text-lumi-blue'
                                                    : 'px-4 py-3 text-foreground/80'
                                            }
                                        >
                                            {l.key_source === 'user'
                                                ? 'Sendiri'
                                                : 'Platform'}
                                        </td>
                                        <td className="px-4 py-3 text-right font-mono">
                                            {number(l.input_tokens)} /{' '}
                                            {number(l.output_tokens)}
                                        </td>
                                        <td className="px-4 py-3 text-right font-mono">
                                            {latency(l.latency_ms)}
                                        </td>
                                        <td className="px-4 py-3">
                                            <UsageStatus
                                                status={l.status}
                                                code={l.error_code}
                                            />
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                    <Pagination page={logs} noun="baris" />
                </section>
            </div>
        </>
    );
}

Logs.layout = {
    breadcrumbs: [{ title: 'Log pemakaian', href: logsIndex() }],
};

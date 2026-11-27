import { Head, router } from '@inertiajs/react';
import type { Paginated } from '@/components/console/table';
import { Pagination, Pill, Th } from '@/components/console/table';
import { Label } from '@/components/ui/label';
import { latency, shortTime } from '@/lib/format';
import { index as auditIndex } from '@/routes/console/audit';

type AuditEntry = {
    id: string;
    at: string | null;
    user: string | null;
    tool_name: string;
    mode: string;
    status: string;
    summary: string | null;
    latency_ms: number | null;
};

type Filters = { user: string; tool: string; status: string; date: string };

type Props = {
    filters: Filters;
    logs: Paginated<AuditEntry>;
    users: { id: number; name: string }[];
    tools: string[];
};

const selectClass =
    'h-[42px] rounded-[10px] border border-input bg-card px-3 text-sm';

export default function AuditPage({ filters, logs, users, tools }: Props) {
    const apply = (changes: Partial<Filters>) => {
        const next = { ...filters, ...changes };
        const query = Object.fromEntries(
            Object.entries(next).filter(([, v]) => v !== ''),
        );
        router.get(
            auditIndex.url({ query }),
            {},
            { preserveState: true, preserveScroll: true },
        );
    };

    return (
        <>
            <Head title="Audit log" />
            <div className="flex flex-col gap-5 p-4 md:p-8">
                <header className="flex flex-col gap-1.5">
                    <h1 className="font-display text-[28px] font-semibold">
                        Audit log
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Riwayat eksekusi tool dan persetujuan aksi. Isi
                        percakapan dan API key tidak pernah ditampilkan di sini.
                    </p>
                </header>

                <form
                    aria-label="Saring audit log"
                    onSubmit={(e) => e.preventDefault()}
                    className="grid items-end gap-3 sm:grid-cols-2 xl:grid-cols-4"
                >
                    <div className="flex flex-col gap-1.5">
                        <Label
                            htmlFor="a-user"
                            className="text-xs text-muted-foreground"
                        >
                            User
                        </Label>
                        <select
                            id="a-user"
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
                            htmlFor="a-tool"
                            className="text-xs text-muted-foreground"
                        >
                            Tool
                        </Label>
                        <select
                            id="a-tool"
                            value={filters.tool}
                            onChange={(e) => apply({ tool: e.target.value })}
                            className={selectClass}
                        >
                            <option value="">Semua tool</option>
                            {tools.map((t) => (
                                <option key={t} value={t}>
                                    {t}
                                </option>
                            ))}
                        </select>
                    </div>
                    <div className="flex flex-col gap-1.5">
                        <Label
                            htmlFor="a-status"
                            className="text-xs text-muted-foreground"
                        >
                            Status
                        </Label>
                        <select
                            id="a-status"
                            value={filters.status}
                            onChange={(e) => apply({ status: e.target.value })}
                            className={selectClass}
                        >
                            <option value="">Semua status</option>
                            <option value="executed">Dieksekusi</option>
                            <option value="approved">Disetujui</option>
                            <option value="rejected">Ditolak user</option>
                            <option value="expired">Kedaluwarsa</option>
                            <option value="denied">Ditolak aturan</option>
                            <option value="error">Error</option>
                        </select>
                    </div>
                    <div className="flex flex-col gap-1.5">
                        <Label
                            htmlFor="a-date"
                            className="text-xs text-muted-foreground"
                        >
                            Tanggal
                        </Label>
                        <input
                            id="a-date"
                            type="date"
                            value={filters.date}
                            onChange={(e) => apply({ date: e.target.value })}
                            className={selectClass}
                        />
                    </div>
                </form>

                <section
                    aria-label="Daftar audit log"
                    className="overflow-hidden rounded-2xl border bg-card"
                >
                    <div className="overflow-x-auto">
                        <table className="w-full min-w-[900px] border-collapse text-[13px]">
                            <thead>
                                <tr className="text-left text-muted-foreground">
                                    <Th className="px-4">Waktu</Th>
                                    <Th className="px-4">User</Th>
                                    <Th className="px-4">Tool</Th>
                                    <Th className="px-4">Mode</Th>
                                    <Th className="px-4">Status</Th>
                                    <Th className="px-4 text-right">Latensi</Th>
                                    <Th className="px-4">Ringkasan</Th>
                                </tr>
                            </thead>
                            <tbody>
                                {logs.data.map((entry) => (
                                    <tr
                                        key={entry.id}
                                        className="border-b border-border/70"
                                    >
                                        <td className="px-4 py-3 font-mono text-muted-foreground">
                                            {shortTime(entry.at)}
                                        </td>
                                        <td className="px-4 py-3">
                                            {entry.user ?? '–'}
                                        </td>
                                        <td className="px-4 py-3 font-mono">
                                            {entry.tool_name}
                                        </td>
                                        <td className="px-4 py-3 font-mono text-muted-foreground">
                                            {entry.mode}
                                        </td>
                                        <td className="px-4 py-3">
                                            <AuditStatus
                                                status={entry.status}
                                            />
                                        </td>
                                        <td className="px-4 py-3 text-right font-mono">
                                            {entry.latency_ms === null
                                                ? '–'
                                                : latency(entry.latency_ms)}
                                        </td>
                                        <td
                                            className="max-w-[300px] truncate px-4 py-3 text-muted-foreground"
                                            title={entry.summary ?? ''}
                                        >
                                            {entry.summary ?? '–'}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                    <Pagination page={logs} noun="entri" />
                </section>
            </div>
        </>
    );
}

function AuditStatus({ status }: { status: string }) {
    switch (status) {
        case 'executed':
            return <Pill tone="lime">Dieksekusi</Pill>;
        case 'approved':
            return <Pill tone="lime">Disetujui</Pill>;
        case 'rejected':
            return <Pill tone="amber">Ditolak user</Pill>;
        case 'expired':
            return <Pill tone="plain">Kedaluwarsa</Pill>;
        case 'denied':
            return <Pill tone="coral">Ditolak aturan</Pill>;
        default:
            return <Pill tone="coral">Error</Pill>;
    }
}

AuditPage.layout = {
    breadcrumbs: [{ title: 'Audit log', href: auditIndex() }],
};

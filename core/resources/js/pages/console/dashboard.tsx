import { Head, Link } from '@inertiajs/react';
import { useState } from 'react';
import { ErrorBadge, Th } from '@/components/console/table';
import { compactNumber, longDate, shortTime } from '@/lib/format';
import { cn } from '@/lib/utils';
import { dashboard } from '@/routes/console';
import { index as logsIndex } from '@/routes/console/logs';
import { index as providersIndex } from '@/routes/console/providers';

type Props = {
    today: string;
    stats: {
        users: number;
        unverified: number;
        blocked: number;
        messages: number;
        messages_platform: number;
        messages_user: number;
        input_tokens: number;
        output_tokens: number;
        errors: number;
        top_error: string | null;
    };
    series: { date: string; messages: number; tokens: number }[];
    defaultModel: {
        label: string;
        model_id: string;
        provider: string;
        key_last4: string | null;
        last_tested_at: string | null;
        last_error: string | null;
    } | null;
    defaultQuota: number;
    recentErrors: {
        id: number;
        at: string | null;
        user: string | null;
        model: string;
        error_code: string | null;
        key_source: string;
    }[];
};

export default function Dashboard({
    today,
    stats,
    series,
    defaultModel,
    defaultQuota,
    recentErrors,
}: Props) {
    return (
        <>
            <Head title="Dashboard" />
            <div className="flex flex-col gap-6 p-4 md:p-8">
                <header className="flex flex-col gap-1.5">
                    <h1 className="font-display text-[28px] font-semibold">
                        Dashboard
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        {longDate(today)} · hari dihitung waktu WIB
                    </p>
                </header>

                <section
                    aria-label="Ringkasan hari ini"
                    className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"
                >
                    <StatCard
                        title="User"
                        value={String(stats.users)}
                        hint={`${stats.unverified} belum verifikasi · ${stats.blocked} diblokir`}
                    />
                    <StatCard
                        title="Pesan hari ini"
                        value={String(stats.messages)}
                        hint={`${stats.messages_platform} key platform · ${stats.messages_user} key sendiri`}
                    />
                    <StatCard
                        title="Token hari ini"
                        value={compactNumber(
                            stats.input_tokens + stats.output_tokens,
                        )}
                        hint={`masuk ${compactNumber(stats.input_tokens)} · keluar ${compactNumber(stats.output_tokens)}`}
                    />
                    <StatCard
                        title="Error hari ini"
                        value={String(stats.errors)}
                        hint={
                            stats.top_error
                                ? `terbanyak: ${stats.top_error}`
                                : 'tidak ada error'
                        }
                        warn={stats.errors > 0}
                    />
                </section>

                <div className="flex flex-wrap gap-4">
                    <ChartCard series={series} />

                    <section
                        aria-labelledby="model-title"
                        className="flex min-w-0 flex-[1_1_280px] flex-col gap-4 rounded-2xl border bg-card p-5"
                    >
                        <h2
                            id="model-title"
                            className="font-display text-[17px] font-semibold"
                        >
                            Model default
                        </h2>
                        {defaultModel ? (
                            <>
                                <div className="flex flex-col gap-1.5">
                                    <p className="text-lg font-semibold">
                                        {defaultModel.label}
                                    </p>
                                    <p className="font-mono text-xs break-all text-muted-foreground">
                                        {defaultModel.model_id}
                                    </p>
                                </div>
                                <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2.5 text-[13px]">
                                    <dt className="text-muted-foreground">
                                        Provider
                                    </dt>
                                    <dd>{defaultModel.provider}</dd>
                                    <dt className="text-muted-foreground">
                                        Key
                                    </dt>
                                    <dd className="font-mono">
                                        •••• {defaultModel.key_last4}
                                    </dd>
                                    <dt className="text-muted-foreground">
                                        Tes terakhir
                                    </dt>
                                    <dd
                                        className={cn(
                                            defaultModel.last_error
                                                ? 'text-lumi-amber'
                                                : 'text-primary',
                                        )}
                                    >
                                        {defaultModel.last_tested_at
                                            ? `${defaultModel.last_error ? 'Gagal' : 'Berhasil'} · ${shortTime(defaultModel.last_tested_at)}`
                                            : 'Belum pernah'}
                                    </dd>
                                    <dt className="text-muted-foreground">
                                        Kuota default
                                    </dt>
                                    <dd>{defaultQuota} pesan / user / hari</dd>
                                </dl>
                            </>
                        ) : (
                            <p className="text-sm leading-relaxed text-lumi-amber">
                                Belum ada model. User belum bisa chat sampai
                                provider dan model dipasang.
                            </p>
                        )}
                        <div className="flex-1" />
                        <Link
                            href={providersIndex()}
                            className="flex min-h-11 items-center justify-center rounded-xl border border-input text-sm font-semibold hover:bg-muted"
                        >
                            Kelola provider &amp; model
                        </Link>
                    </section>
                </div>

                <section
                    aria-labelledby="err-title"
                    className="flex flex-col gap-3 rounded-2xl border bg-card p-5"
                >
                    <div className="flex flex-wrap items-center justify-between gap-3">
                        <h2
                            id="err-title"
                            className="font-display text-[17px] font-semibold"
                        >
                            Error terakhir
                        </h2>
                        <Link
                            href={logsIndex({ query: { status: 'error' } })}
                            className="flex min-h-11 items-center text-sm font-semibold text-primary hover:underline"
                        >
                            Lihat semua log
                        </Link>
                    </div>
                    {recentErrors.length === 0 ? (
                        <p className="py-2 text-sm text-muted-foreground">
                            Belum ada error. Semua jawaban AI lancar.
                        </p>
                    ) : (
                        <div className="overflow-x-auto">
                            <table className="w-full min-w-[680px] border-collapse text-[13px]">
                                <thead>
                                    <tr className="text-left text-muted-foreground">
                                        <Th>Waktu</Th>
                                        <Th>User</Th>
                                        <Th>Model</Th>
                                        <Th>Kode</Th>
                                        <Th>Sumber key</Th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {recentErrors.map((e) => (
                                        <tr
                                            key={e.id}
                                            className="border-b border-border/70 last:border-0"
                                        >
                                            <td className="px-3 py-3 font-mono text-muted-foreground">
                                                {shortTime(e.at)}
                                            </td>
                                            <td className="px-3 py-3">
                                                {e.user ?? '–'}
                                            </td>
                                            <td className="px-3 py-3 font-mono">
                                                {e.model}
                                            </td>
                                            <td className="px-3 py-3">
                                                <ErrorBadge
                                                    code={e.error_code}
                                                />
                                            </td>
                                            <td className="px-3 py-3">
                                                {e.key_source === 'user'
                                                    ? 'Key sendiri'
                                                    : 'Platform'}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    )}
                </section>
            </div>
        </>
    );
}

function StatCard({
    title,
    value,
    hint,
    warn = false,
}: {
    title: string;
    value: string;
    hint: string;
    warn?: boolean;
}) {
    return (
        <article className="flex flex-col gap-2.5 rounded-2xl border bg-card px-5 py-4">
            <h2 className="text-[13px] font-medium text-muted-foreground">
                {title}
            </h2>
            <p
                className={cn(
                    'font-display text-[34px] leading-none font-semibold',
                    warn && 'text-lumi-amber',
                )}
            >
                {value}
            </p>
            <p className="text-[13px] text-muted-foreground">{hint}</p>
        </article>
    );
}

function ChartCard({ series }: { series: Props['series'] }) {
    const [mode, setMode] = useState<'messages' | 'tokens'>('messages');
    const values = series.map((d) =>
        mode === 'messages' ? d.messages : d.tokens,
    );
    const max = Math.max(1, ...values);
    const last = values[values.length - 1] ?? 0;
    const label = (v: number) =>
        mode === 'messages' ? String(v) : compactNumber(v);

    return (
        <section
            aria-labelledby="chart-title"
            className="flex min-w-0 flex-[2_1_520px] flex-col gap-4 rounded-2xl border bg-card p-5"
        >
            <div className="flex flex-wrap items-center justify-between gap-3">
                <h2
                    id="chart-title"
                    className="font-display text-[17px] font-semibold"
                >
                    14 hari terakhir
                </h2>
                <div
                    role="group"
                    aria-label="Pilih data grafik"
                    className="flex gap-1 rounded-xl border bg-background p-1"
                >
                    {(['messages', 'tokens'] as const).map((m) => (
                        <button
                            key={m}
                            type="button"
                            aria-pressed={mode === m}
                            onClick={() => setMode(m)}
                            className={cn(
                                'min-h-9 rounded-[9px] px-3.5 text-[13px] font-semibold',
                                mode === m
                                    ? 'bg-secondary text-foreground'
                                    : 'text-muted-foreground hover:text-foreground',
                            )}
                        >
                            {m === 'messages' ? 'Pesan' : 'Token'}
                        </button>
                    ))}
                </div>
            </div>
            <p className="text-[13px] text-muted-foreground">
                {mode === 'messages'
                    ? `Jawaban AI per hari, semua user. Hari ini ${last}.`
                    : `Token per hari, masuk + keluar. Hari ini ${compactNumber(last)}.`}
            </p>
            <div
                role="img"
                aria-label={`Grafik batang ${mode === 'messages' ? 'pesan' : 'token'} per hari selama 14 hari terakhir: ${values.map(label).join(', ')}`}
                className="flex h-[220px] items-end gap-2 border-b border-input pb-1"
            >
                {series.map((d, i) => {
                    const v = values[i];
                    const isToday = i === series.length - 1;

                    return (
                        <div
                            key={d.date}
                            className="flex h-full min-w-0 flex-1 flex-col items-center justify-end gap-1.5"
                        >
                            <span className="font-mono text-[11px] text-muted-foreground">
                                {v > 0 ? label(v) : ''}
                            </span>
                            <span
                                className={cn(
                                    'w-full max-w-[34px] rounded-t-md rounded-b-[2px]',
                                    mode === 'messages'
                                        ? isToday
                                            ? 'bg-chart-1'
                                            : 'bg-chart-4'
                                        : isToday
                                          ? 'bg-chart-2'
                                          : 'bg-chart-5',
                                )}
                                style={{
                                    height: `${Math.max(v > 0 ? 4 : 2, Math.round((v / max) * 180))}px`,
                                }}
                            />
                        </div>
                    );
                })}
            </div>
            <div aria-hidden="true" className="flex gap-2">
                {series.map((d) => (
                    <span
                        key={d.date}
                        className="min-w-0 flex-1 text-center font-mono text-[11px] text-muted-foreground"
                    >
                        {d.date.slice(8)}
                    </span>
                ))}
            </div>
        </section>
    );
}

Dashboard.layout = {
    breadcrumbs: [{ title: 'Dashboard', href: dashboard() }],
};

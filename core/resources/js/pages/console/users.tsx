import { Head, router, useForm } from '@inertiajs/react';
import { Search, Smartphone } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Pill } from '@/components/console/table';
import type { Paginated } from '@/components/console/table';
import { Pagination, Th } from '@/components/console/table';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { relativeTime, shortDate, shortTime } from '@/lib/format';
import { cn } from '@/lib/utils';
import {
    block,
    index as usersIndex,
    quota,
    unblock,
} from '@/routes/console/users';
import { destroy as revokeDevice } from '@/routes/console/users/devices';

type Filter = 'all' | 'unverified' | 'blocked' | 'own_key';

type UserRow = {
    id: number;
    name: string;
    email: string;
    role: 'superadmin' | 'user';
    is_blocked: boolean;
    email_verified: boolean;
    own_key: boolean;
    quota_used: number | null;
    quota_limit: number;
    devices: number;
};

type UserDetail = UserRow & {
    joined: string | null;
    daily_quota: number | null;
    can_block: boolean;
    ai_key: {
        driver: string;
        base_url: string | null;
        model_id: string;
        key_last4: string;
        is_active: boolean;
        last_validated_at: string | null;
        last_error: string | null;
    } | null;
    device_list: {
        id: number;
        name: string;
        last_used_at: string | null;
        created_at: string | null;
    }[];
};

type Props = {
    filters: { q: string; filter: Filter };
    counts: Record<Filter, number>;
    registrationOpen: boolean;
    users: Paginated<UserRow>;
    selected: UserDetail | null;
};

const FILTER_LABELS: Record<Filter, string> = {
    all: 'Semua',
    unverified: 'Belum verifikasi',
    blocked: 'Diblokir',
    own_key: 'Pakai key sendiri',
};

export default function Users({
    filters,
    counts,
    registrationOpen,
    users,
    selected,
}: Props) {
    const [q, setQ] = useState(filters.q);
    const first = useRef(true);

    // Search as you type (debounced), keeping the current filter.
    useEffect(() => {
        if (first.current) {
            first.current = false;

            return;
        }

        const t = setTimeout(() => {
            router.get(
                usersIndex.url({
                    query: { q: q || undefined, filter: filters.filter },
                }),
                {},
                { preserveState: true, replace: true },
            );
        }, 300);

        return () => clearTimeout(t);
    }, [q, filters.filter]);

    const visit = (query: Record<string, string | number | undefined>) =>
        router.get(
            usersIndex.url({
                query: {
                    q: filters.q || undefined,
                    filter: filters.filter,
                    ...query,
                },
            }),
            {},
            { preserveState: true, preserveScroll: true },
        );

    return (
        <>
            <Head title="Users" />
            <div className="flex flex-col gap-5 p-4 md:p-8">
                <header className="flex flex-col gap-1.5">
                    <h1 className="font-display text-[28px] font-semibold">
                        Users
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        {counts.all} akun · pendaftaran{' '}
                        {registrationOpen ? 'terbuka' : 'ditutup'}
                    </p>
                </header>

                <div className="flex flex-wrap items-center gap-3">
                    <div className="flex h-11 flex-[1_1_280px] items-center gap-2.5 rounded-xl border border-input bg-card px-3.5 text-muted-foreground">
                        <Search className="size-[18px]" aria-hidden="true" />
                        <label htmlFor="user-search" className="sr-only">
                            Cari user
                        </label>
                        <input
                            id="user-search"
                            type="search"
                            value={q}
                            onChange={(e) => setQ(e.target.value)}
                            placeholder="Cari nama atau email"
                            className="h-10 min-w-0 flex-1 bg-transparent text-sm text-foreground outline-none"
                        />
                    </div>
                    <div
                        role="group"
                        aria-label="Saring user"
                        className="flex flex-wrap gap-2"
                    >
                        {(Object.keys(FILTER_LABELS) as Filter[]).map((f) => (
                            <button
                                key={f}
                                type="button"
                                aria-pressed={filters.filter === f}
                                onClick={() =>
                                    visit({ filter: f, user: undefined })
                                }
                                className={cn(
                                    'min-h-10 rounded-full border px-3.5 text-[13px]',
                                    filters.filter === f
                                        ? 'border-primary bg-accent font-semibold text-accent-foreground'
                                        : 'border-input font-medium text-foreground/80 hover:bg-muted',
                                )}
                            >
                                {FILTER_LABELS[f]} · {counts[f]}
                            </button>
                        ))}
                    </div>
                </div>

                <div className="flex flex-wrap items-start gap-4">
                    <section
                        aria-label="Daftar user"
                        className="min-w-0 flex-[3_1_560px] overflow-hidden rounded-2xl border bg-card"
                    >
                        <div className="overflow-x-auto">
                            <table className="w-full min-w-[680px] border-collapse text-[13px]">
                                <thead>
                                    <tr className="text-left text-muted-foreground">
                                        <Th className="px-4">User</Th>
                                        <Th className="px-4">Status</Th>
                                        <Th className="px-4">Kuota hari ini</Th>
                                        <Th className="px-4">Key AI</Th>
                                        <Th className="px-4">Perangkat</Th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {users.data.map((u) => (
                                        <tr
                                            key={u.id}
                                            className={cn(
                                                'border-b border-border/70',
                                                selected?.id === u.id &&
                                                    'bg-muted',
                                            )}
                                        >
                                            <td className="px-4 py-2.5">
                                                <button
                                                    type="button"
                                                    aria-pressed={
                                                        selected?.id === u.id
                                                    }
                                                    onClick={() =>
                                                        visit({
                                                            user: u.id,
                                                            page: undefined,
                                                        })
                                                    }
                                                    className="flex min-h-11 w-full items-center gap-3 text-left"
                                                >
                                                    <Avatar name={u.name} />
                                                    <span className="flex min-w-0 flex-col gap-0.5">
                                                        <span className="text-sm font-semibold">
                                                            {u.name}
                                                        </span>
                                                        <span className="truncate text-muted-foreground">
                                                            {u.email}
                                                        </span>
                                                    </span>
                                                </button>
                                            </td>
                                            <td className="px-4 py-2.5">
                                                <StatusPill user={u} />
                                            </td>
                                            <td className="px-4 py-2.5">
                                                <QuotaBar user={u} />
                                            </td>
                                            <td
                                                className={cn(
                                                    'px-4 py-2.5',
                                                    u.own_key
                                                        ? 'text-lumi-blue'
                                                        : 'text-foreground/80',
                                                )}
                                            >
                                                {u.own_key
                                                    ? 'Key sendiri'
                                                    : 'Platform'}
                                            </td>
                                            <td className="px-4 py-2.5 font-mono">
                                                {u.devices}
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                        <Pagination page={users} noun="user" />
                    </section>

                    {selected && (
                        <UserPanel key={selected.id} user={selected} />
                    )}
                </div>
            </div>
        </>
    );
}

function Avatar({ name, large = false }: { name: string; large?: boolean }) {
    return (
        <span
            aria-hidden="true"
            className={cn(
                'flex shrink-0 items-center justify-center rounded-full bg-secondary font-display font-semibold',
                large
                    ? 'size-12 text-xl text-primary'
                    : 'size-[34px] text-foreground/80',
            )}
        >
            {name.slice(0, 1).toUpperCase()}
        </span>
    );
}

function StatusPill({ user }: { user: UserRow }) {
    if (user.is_blocked) {
        return <Pill tone="coral">Diblokir</Pill>;
    }

    if (user.role === 'superadmin') {
        return <Pill tone="lime">Superadmin</Pill>;
    }

    if (!user.email_verified) {
        return <Pill tone="amber">Belum verifikasi</Pill>;
    }

    return <Pill tone="plain">Aktif</Pill>;
}

function QuotaBar({ user }: { user: UserRow }) {
    if (user.quota_used === null) {
        return <span className="text-muted-foreground">Tidak dihitung</span>;
    }

    const pct =
        user.quota_limit > 0
            ? Math.min(
                  100,
                  Math.round((user.quota_used / user.quota_limit) * 100),
              )
            : 100;

    return (
        <div className="flex min-w-[120px] flex-col gap-1.5">
            <span>
                {user.quota_used} / {user.quota_limit}
            </span>
            <span
                aria-hidden="true"
                className="flex h-1.5 overflow-hidden rounded-full bg-input"
            >
                <span
                    className={pct >= 100 ? 'bg-lumi-amber' : 'bg-primary'}
                    style={{ width: `${pct}%` }}
                />
            </span>
        </div>
    );
}

function UserPanel({ user }: { user: UserDetail }) {
    const form = useForm({
        daily_quota: user.daily_quota === null ? '' : String(user.daily_quota),
    });

    const saveQuota = (e: React.FormEvent) => {
        e.preventDefault();
        form.transform((data) => ({
            daily_quota:
                data.daily_quota === '' ? null : Number(data.daily_quota),
        }));
        form.submit(quota(user.id), { preserveScroll: true });
    };

    const toggleBlock = () => {
        if (user.is_blocked) {
            router.visit(unblock(user.id), { preserveScroll: true });

            return;
        }

        if (
            window.confirm(
                `Blokir ${user.name}? Semua perangkatnya langsung keluar.`,
            )
        ) {
            router.visit(block(user.id), { preserveScroll: true });
        }
    };

    return (
        <aside
            aria-labelledby="detail-title"
            className="flex min-w-0 flex-[1_1_320px] flex-col gap-5 rounded-2xl border bg-card p-5"
        >
            <div className="flex items-center gap-3.5">
                <Avatar name={user.name} large />
                <div className="flex min-w-0 flex-col gap-1">
                    <h2
                        id="detail-title"
                        className="font-display text-[19px] font-semibold"
                    >
                        {user.name}
                    </h2>
                    <span className="text-[13px] break-all text-muted-foreground">
                        {user.email} · daftar {shortDate(user.joined)}
                    </span>
                </div>
            </div>

            <form onSubmit={saveQuota} className="flex flex-col gap-2">
                <Label
                    htmlFor="quota-input"
                    className="text-[13px] text-muted-foreground"
                >
                    Kuota harian (key platform)
                </Label>
                <div className="flex gap-2">
                    <Input
                        id="quota-input"
                        type="number"
                        min={0}
                        value={form.data.daily_quota}
                        onChange={(e) =>
                            form.setData('daily_quota', e.target.value)
                        }
                        placeholder={`${user.quota_limit} (ikut default)`}
                        className="h-11"
                    />
                    <Button
                        type="submit"
                        className="h-11"
                        disabled={form.processing}
                    >
                        Simpan
                    </Button>
                </div>
                <InputError message={form.errors.daily_quota} />
                <span className="text-xs text-muted-foreground">
                    Kosongkan untuk ikut kuota default. Pesan dengan key sendiri
                    tidak dihitung.
                </span>
            </form>

            <div className="flex flex-col gap-1.5">
                <span className="text-[13px] font-medium text-muted-foreground">
                    Key AI
                </span>
                {user.ai_key ? (
                    <>
                        <span className="text-sm">
                            {user.ai_key.driver === 'openrouter'
                                ? 'OpenRouter'
                                : (user.ai_key.base_url ?? 'Kompatibel OpenAI')}
                            {' · '}
                            <span className="font-mono">
                                {user.ai_key.model_id}
                            </span>
                            {' · '}
                            <span className="font-mono">
                                •••• {user.ai_key.key_last4}
                            </span>
                        </span>
                        <span
                            className={cn(
                                'text-xs',
                                user.ai_key.last_error
                                    ? 'text-lumi-amber'
                                    : 'text-muted-foreground',
                            )}
                        >
                            {user.ai_key.is_active ? 'Aktif' : 'Dimatikan user'}
                            {' · '}
                            {user.ai_key.last_error ??
                                `diuji ${relativeTime(user.ai_key.last_validated_at)}`}
                        </span>
                    </>
                ) : (
                    <span className="text-sm">Memakai key platform.</span>
                )}
                <span className="text-xs text-muted-foreground">
                    Isi key tidak pernah ditampilkan.
                </span>
            </div>

            <div className="flex flex-col gap-2.5">
                <span className="text-[13px] font-medium text-muted-foreground">
                    Perangkat aktif
                </span>
                {user.device_list.length === 0 && (
                    <span className="text-[13px] text-muted-foreground">
                        Tidak ada perangkat yang sedang masuk.
                    </span>
                )}
                {user.device_list.map((d) => (
                    <div
                        key={d.id}
                        className="flex items-center gap-3 rounded-xl border bg-background px-3 py-2.5"
                    >
                        <Smartphone
                            className="size-[18px] text-muted-foreground"
                            aria-hidden="true"
                        />
                        <span className="flex min-w-0 flex-1 flex-col gap-0.5">
                            <span className="truncate text-sm font-medium">
                                {d.name}
                            </span>
                            <span className="text-xs text-muted-foreground">
                                {d.last_used_at
                                    ? `Aktif ${relativeTime(d.last_used_at)}`
                                    : `Masuk ${shortTime(d.created_at)}`}
                            </span>
                        </span>
                        <Button
                            type="button"
                            variant="outline"
                            size="sm"
                            aria-label={`Keluarkan ${d.name}`}
                            onClick={() =>
                                router.visit(
                                    revokeDevice({
                                        user: user.id,
                                        token: d.id,
                                    }),
                                    { preserveScroll: true },
                                )
                            }
                        >
                            Keluarkan
                        </Button>
                    </div>
                ))}
            </div>

            {user.can_block && (
                <>
                    <div className="h-px bg-border" />
                    <div className="flex flex-col gap-2">
                        <Button
                            type="button"
                            variant="outline"
                            onClick={toggleBlock}
                            className={cn(
                                'h-11',
                                !user.is_blocked &&
                                    'border-[#5c3a36] text-lumi-coral hover:text-lumi-coral',
                            )}
                        >
                            {user.is_blocked ? 'Buka blokir' : 'Blokir user'}
                        </Button>
                        <span className="text-xs text-muted-foreground">
                            {user.is_blocked
                                ? 'User bisa masuk dan chat lagi.'
                                : 'Semua perangkatnya langsung keluar dan tidak bisa masuk lagi.'}
                        </span>
                    </div>
                </>
            )}
        </aside>
    );
}

Users.layout = {
    breadcrumbs: [{ title: 'Users', href: usersIndex() }],
};

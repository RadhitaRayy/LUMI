import { Link } from '@inertiajs/react';
import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

export function Th({
    children,
    className,
}: {
    children: ReactNode;
    className?: string;
}) {
    return (
        <th
            scope="col"
            className={cn(
                'border-b border-input px-3 py-2.5 font-medium',
                className,
            )}
        >
            {children}
        </th>
    );
}

export function ErrorBadge({ code }: { code: string | null }) {
    return (
        <span className="inline-flex items-center rounded-full bg-[#2e2410] px-2.5 py-0.5 font-mono text-xs text-lumi-amber">
            {code ?? 'error'}
        </span>
    );
}

const TONES = {
    lime: 'bg-accent text-accent-foreground',
    plain: 'bg-secondary text-foreground',
    amber: 'bg-[#2e2410] text-lumi-amber',
    coral: 'bg-[#2a1e1e] text-lumi-coral',
} as const;

export function Pill({
    tone,
    children,
}: {
    tone: keyof typeof TONES;
    children: ReactNode;
}) {
    return (
        <span
            className={cn(
                'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap',
                TONES[tone],
            )}
        >
            {children}
        </span>
    );
}

/** Usage status: complete / cancelled / error (with its code). */
export function UsageStatus({
    status,
    code,
}: {
    status: string;
    code: string | null;
}) {
    if (status === 'complete') {
        return <Pill tone="lime">Selesai</Pill>;
    }

    if (status === 'cancelled') {
        return <Pill tone="plain">Dibatalkan</Pill>;
    }

    return <ErrorBadge code={code} />;
}

export type Paginated<T> = {
    data: T[];
    from: number | null;
    to: number | null;
    total: number;
    prev_page_url: string | null;
    next_page_url: string | null;
};

export function Pagination({
    page,
    noun,
}: {
    page: Paginated<unknown>;
    noun: string;
}) {
    const button =
        'flex min-h-10 items-center rounded-[10px] border border-input px-3.5 text-[13px] font-semibold';

    return (
        <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 text-[13px] text-muted-foreground">
            <span>
                {page.total === 0
                    ? `Tidak ada ${noun}`
                    : `Menampilkan ${page.from}–${page.to} dari ${page.total} ${noun}`}
            </span>
            <div className="flex gap-2">
                {page.prev_page_url ? (
                    <Link
                        href={page.prev_page_url}
                        preserveScroll
                        className={cn(button, 'text-foreground hover:bg-muted')}
                    >
                        Sebelumnya
                    </Link>
                ) : (
                    <span className={cn(button, 'border-border opacity-50')}>
                        Sebelumnya
                    </span>
                )}
                {page.next_page_url ? (
                    <Link
                        href={page.next_page_url}
                        preserveScroll
                        className={cn(button, 'text-foreground hover:bg-muted')}
                    >
                        Berikutnya
                    </Link>
                ) : (
                    <span className={cn(button, 'border-border opacity-50')}>
                        Berikutnya
                    </span>
                )}
            </div>
        </div>
    );
}

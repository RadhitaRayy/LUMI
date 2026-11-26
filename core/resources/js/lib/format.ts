/** Display helpers for Lumi Console (Indonesian, times in WIB). */

const TZ = 'Asia/Jakarta';

/** 21600 → "21,6 rb", 950 → "950". */
export function compactNumber(value: number): string {
    if (value < 1000) {
        return String(value);
    }

    const thousands = value / 1000;

    return `${thousands.toLocaleString('id-ID', { maximumFractionDigits: thousands < 100 ? 1 : 0 })} rb`;
}

export function number(value: number): string {
    return value.toLocaleString('id-ID');
}

/** "11.42" for today, "25 Nov 11.42" otherwise. */
export function shortTime(iso: string | null | undefined): string {
    if (!iso) {
        return '–';
    }

    const date = new Date(iso);
    const time = date.toLocaleTimeString('id-ID', {
        timeZone: TZ,
        hour: '2-digit',
        minute: '2-digit',
    });
    const day = (d: Date) => d.toLocaleDateString('en-CA', { timeZone: TZ });

    if (day(date) === day(new Date())) {
        return time;
    }

    return `${date.toLocaleDateString('id-ID', { timeZone: TZ, day: 'numeric', month: 'short' })} ${time}`;
}

/** "26 Nov 2026". */
export function shortDate(iso: string | null | undefined): string {
    if (!iso) {
        return '–';
    }

    return new Date(iso).toLocaleDateString('id-ID', {
        timeZone: TZ,
        day: 'numeric',
        month: 'short',
        year: 'numeric',
    });
}

export function longDate(isoDate: string): string {
    return new Date(`${isoDate}T12:00:00+07:00`).toLocaleDateString('id-ID', {
        timeZone: TZ,
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
    });
}

/** "2 menit lalu", "3 jam lalu", else a date. */
export function relativeTime(iso: string | null | undefined): string {
    if (!iso) {
        return 'belum pernah';
    }

    const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60000);

    if (minutes < 1) {
        return 'baru saja';
    }

    if (minutes < 60) {
        return `${minutes} menit lalu`;
    }

    if (minutes < 60 * 24) {
        return `${Math.round(minutes / 60)} jam lalu`;
    }

    return shortTime(iso);
}

export function latency(ms: number): string {
    return `${(ms / 1000).toLocaleString('id-ID', { maximumFractionDigits: 1 })} dtk`;
}

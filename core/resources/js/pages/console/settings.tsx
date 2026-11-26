import { Head, useForm } from '@inertiajs/react';
import { SwitchButton } from '@/components/console/switch-button';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { shortTime } from '@/lib/format';
import { edit, update } from '@/routes/console/settings';

type Settings = {
    registration_open: boolean;
    require_email_verification: boolean;
    default_daily_quota: number;
    system_prompt: string;
    updated_at: string | null;
};

export default function SettingsPage({ settings }: { settings: Settings }) {
    const form = useForm({
        registration_open: settings.registration_open,
        require_email_verification: settings.require_email_verification,
        default_daily_quota: settings.default_daily_quota,
        system_prompt: settings.system_prompt,
    });

    const submit = (e: React.FormEvent) => {
        e.preventDefault();
        form.submit(update(), { preserveScroll: true });
    };

    return (
        <>
            <Head title="Pengaturan" />
            <div className="flex flex-col gap-5 p-4 md:p-8">
                <header className="flex flex-col gap-1.5">
                    <h1 className="font-display text-[28px] font-semibold">
                        Pengaturan
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Berlaku langsung untuk semua user di app.
                    </p>
                </header>

                <form
                    onSubmit={submit}
                    className="flex max-w-[760px] flex-col gap-4"
                >
                    <section
                        aria-labelledby="acc-title"
                        className="rounded-2xl border bg-card px-5 py-2"
                    >
                        <h2
                            id="acc-title"
                            className="mt-3.5 mb-1 font-display text-[17px] font-semibold"
                        >
                            Akun
                        </h2>
                        <ToggleRow
                            id="reg"
                            label="Pendaftaran terbuka"
                            hint={
                                form.data.registration_open
                                    ? 'Siapa pun bisa daftar dari app.'
                                    : 'Tombol Daftar di app menampilkan pesan pendaftaran ditutup.'
                            }
                            checked={form.data.registration_open}
                            onChange={(v) =>
                                form.setData('registration_open', v)
                            }
                        />
                        <ToggleRow
                            id="ver"
                            label="Wajib verifikasi email"
                            hint={
                                form.data.require_email_verification
                                    ? 'User harus memasukkan kode dari email sebelum bisa chat.'
                                    : 'User bisa langsung chat tanpa verifikasi email.'
                            }
                            checked={form.data.require_email_verification}
                            onChange={(v) =>
                                form.setData('require_email_verification', v)
                            }
                            last
                        />
                    </section>

                    <section
                        aria-labelledby="ai-title"
                        className="flex flex-col gap-5 rounded-2xl border bg-card p-5"
                    >
                        <h2
                            id="ai-title"
                            className="font-display text-[17px] font-semibold"
                        >
                            AI
                        </h2>
                        <div className="flex flex-col gap-2">
                            <Label htmlFor="quota" className="text-sm">
                                Kuota harian default
                            </Label>
                            <div className="flex flex-wrap items-center gap-2.5">
                                <Input
                                    id="quota"
                                    type="number"
                                    min={0}
                                    value={form.data.default_daily_quota}
                                    onChange={(e) =>
                                        form.setData(
                                            'default_daily_quota',
                                            Number(e.target.value),
                                        )
                                    }
                                    className="h-11 w-[120px]"
                                />
                                <span className="text-sm text-muted-foreground">
                                    jawaban per user per hari, key platform saja
                                </span>
                            </div>
                            <InputError
                                message={form.errors.default_daily_quota}
                            />
                            <span className="text-xs text-muted-foreground">
                                Kuota per user bisa diatur di halaman Users.
                                Jawaban yang gagal karena provider tidak
                                dihitung.
                            </span>
                        </div>
                        <div className="flex flex-col gap-2">
                            <Label htmlFor="prompt" className="text-sm">
                                System prompt
                            </Label>
                            <textarea
                                id="prompt"
                                rows={5}
                                value={form.data.system_prompt}
                                onChange={(e) =>
                                    form.setData(
                                        'system_prompt',
                                        e.target.value,
                                    )
                                }
                                className="resize-y rounded-xl border border-input bg-background px-3.5 py-3 text-sm leading-relaxed outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
                            />
                            <InputError message={form.errors.system_prompt} />
                            <span className="text-xs text-muted-foreground">
                                Nama pengguna ditambahkan otomatis di akhir
                                prompt.
                            </span>
                        </div>
                    </section>

                    <div className="flex flex-wrap items-center gap-3">
                        <Button
                            type="submit"
                            className="h-11 px-5"
                            disabled={form.processing || !form.isDirty}
                        >
                            {form.processing && <Spinner />}
                            Simpan pengaturan
                        </Button>
                        <span
                            role="status"
                            className="text-[13px] text-muted-foreground"
                        >
                            {form.isDirty
                                ? 'Ada perubahan yang belum disimpan.'
                                : settings.updated_at
                                  ? `Terakhir disimpan ${shortTime(settings.updated_at)}`
                                  : ''}
                        </span>
                    </div>
                </form>
            </div>
        </>
    );
}

function ToggleRow({
    id,
    label,
    hint,
    checked,
    onChange,
    last = false,
}: {
    id: string;
    label: string;
    hint: string;
    checked: boolean;
    onChange: (v: boolean) => void;
    last?: boolean;
}) {
    return (
        <div
            className={
                last
                    ? 'flex items-center gap-4 py-4'
                    : 'flex items-center gap-4 border-b py-4'
            }
        >
            <div className="flex min-w-0 flex-1 flex-col gap-1">
                <span id={`${id}-label`} className="text-[15px] font-medium">
                    {label}
                </span>
                <span className="text-[13px] text-muted-foreground">
                    {hint}
                </span>
            </div>
            <SwitchButton
                checked={checked}
                onChange={onChange}
                labelledBy={`${id}-label`}
            />
        </div>
    );
}

SettingsPage.layout = {
    breadcrumbs: [{ title: 'Pengaturan', href: edit() }],
};

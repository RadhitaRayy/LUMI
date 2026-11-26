import { Head, router, useForm, usePage } from '@inertiajs/react';
import { Plus, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { SwitchButton } from '@/components/console/switch-button';
import { Pill, Th } from '@/components/console/table';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { shortTime } from '@/lib/format';
import {
    defaultMethod as makeDefault,
    destroy as destroyModel,
    store as storeModel,
    update as updateModel,
} from '@/routes/console/models';
import {
    destroy as destroyProvider,
    index as providersIndex,
    key as updateKey,
    store as storeProvider,
    test as testProvider,
    update as updateProvider,
} from '@/routes/console/providers';

type Model = {
    id: number;
    model_id: string;
    label: string;
    is_enabled: boolean;
    is_default: boolean;
};

type Provider = {
    id: number;
    name: string;
    driver: 'openrouter' | 'openai_compatible';
    base_url: string | null;
    key_last4: string | null;
    is_enabled: boolean;
    last_tested_at: string | null;
    last_error: string | null;
    models: Model[];
};

const fieldClass = 'h-11';

export default function Providers({ providers }: { providers: Provider[] }) {
    const { errors } = usePage<{ errors: Record<string, string> }>().props;
    const [adding, setAdding] = useState(providers.length === 0);
    const hasCompatible = providers.some(
        (p) => p.driver === 'openai_compatible',
    );

    return (
        <>
            <Head title="Provider & model" />
            <div className="flex flex-col gap-5 p-4 md:p-8">
                <header className="flex flex-wrap items-end justify-between gap-4">
                    <div className="flex max-w-2xl flex-col gap-1.5">
                        <h1 className="font-display text-[28px] font-semibold">
                            Provider &amp; model
                        </h1>
                        <p className="text-sm leading-relaxed text-muted-foreground">
                            Key platform dipakai user yang tidak memasang key
                            sendiri. Key disimpan terenkripsi dan tidak pernah
                            ditampilkan lagi.
                        </p>
                    </div>
                    <Button
                        type="button"
                        className="h-11"
                        aria-expanded={adding}
                        onClick={() => setAdding(!adding)}
                    >
                        <Plus aria-hidden="true" />
                        Tambah provider
                    </Button>
                </header>

                {(errors.model || errors.provider) && (
                    <p
                        role="alert"
                        className="rounded-xl bg-[#2e2410] px-4 py-3 text-sm text-lumi-amber"
                    >
                        {errors.model ?? errors.provider}
                    </p>
                )}

                {adding && <NewProviderForm onDone={() => setAdding(false)} />}

                {providers.length === 0 && !adding && (
                    <p className="rounded-2xl border border-dashed p-6 text-sm text-lumi-amber">
                        Belum ada provider. User belum bisa chat sampai satu
                        provider dan model dipasang.
                    </p>
                )}

                {providers.map((p) => (
                    <ProviderCard key={p.id} provider={p} />
                ))}

                {providers.length > 0 && !hasCompatible && (
                    <section className="flex flex-wrap items-center gap-4 rounded-2xl border border-dashed bg-sidebar p-5">
                        <div className="flex flex-[1_1_320px] flex-col gap-1.5">
                            <h2 className="font-display text-[17px] font-semibold">
                                NVIDIA NIM belum dipasang
                            </h2>
                            <p className="text-[13px] leading-relaxed text-muted-foreground">
                                Provider kedua untuk cadangan kalau model gratis
                                OpenRouter sedang dibatasi. Ambil key gratis di
                                build.nvidia.com.
                            </p>
                        </div>
                        <Button
                            type="button"
                            variant="outline"
                            className="h-11"
                            onClick={() => setAdding(true)}
                        >
                            Pasang NVIDIA NIM
                        </Button>
                    </section>
                )}
            </div>
        </>
    );
}

function NewProviderForm({ onDone }: { onDone: () => void }) {
    const form = useForm({
        name: 'NVIDIA NIM',
        driver: 'openai_compatible' as Provider['driver'],
        base_url: 'https://integrate.api.nvidia.com/v1',
        api_key: '',
        model_id: 'meta/llama-3.1-8b-instruct',
        label: '',
    });

    const submit = (e: React.FormEvent) => {
        e.preventDefault();
        form.submit(storeProvider(), {
            preserveScroll: true,
            onSuccess: () => {
                form.reset();
                onDone();
            },
            onError: () => form.reset('api_key'),
        });
    };

    return (
        <section
            aria-labelledby="new-title"
            className="flex flex-col gap-4 rounded-2xl border border-primary bg-card p-5"
        >
            <h2
                id="new-title"
                className="font-display text-[17px] font-semibold"
            >
                Provider baru
            </h2>
            <form onSubmit={submit} className="flex flex-col gap-4">
                <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                    <Field label="Nama" id="p-name" error={form.errors.name}>
                        <Input
                            id="p-name"
                            value={form.data.name}
                            onChange={(e) =>
                                form.setData('name', e.target.value)
                            }
                            className={fieldClass}
                            required
                        />
                    </Field>
                    <Field
                        label="Jenis"
                        id="p-driver"
                        error={form.errors.driver}
                    >
                        <select
                            id="p-driver"
                            value={form.data.driver}
                            onChange={(e) =>
                                form.setData(
                                    'driver',
                                    e.target.value as Provider['driver'],
                                )
                            }
                            className="h-11 rounded-md border border-input bg-background px-3 text-sm"
                        >
                            <option value="openai_compatible">
                                Kompatibel OpenAI (base URL sendiri)
                            </option>
                            <option value="openrouter">OpenRouter</option>
                        </select>
                    </Field>
                    {form.data.driver === 'openai_compatible' && (
                        <Field
                            label="Base URL"
                            id="p-url"
                            error={form.errors.base_url}
                        >
                            <Input
                                id="p-url"
                                type="url"
                                value={form.data.base_url}
                                onChange={(e) =>
                                    form.setData('base_url', e.target.value)
                                }
                                className={`${fieldClass} font-mono`}
                                required
                            />
                        </Field>
                    )}
                    <Field
                        label="API key"
                        id="p-key"
                        error={form.errors.api_key}
                    >
                        <Input
                            id="p-key"
                            type="password"
                            autoComplete="off"
                            value={form.data.api_key}
                            onChange={(e) =>
                                form.setData('api_key', e.target.value)
                            }
                            className={fieldClass}
                            required
                        />
                    </Field>
                    <Field
                        label="Model pertama"
                        id="p-model"
                        error={form.errors.model_id}
                    >
                        <Input
                            id="p-model"
                            value={form.data.model_id}
                            onChange={(e) =>
                                form.setData('model_id', e.target.value)
                            }
                            className={`${fieldClass} font-mono`}
                            required
                        />
                    </Field>
                    <Field
                        label="Label (opsional)"
                        id="p-label"
                        error={form.errors.label}
                    >
                        <Input
                            id="p-label"
                            value={form.data.label}
                            onChange={(e) =>
                                form.setData('label', e.target.value)
                            }
                            className={fieldClass}
                            placeholder="Llama 3.1 8B"
                        />
                    </Field>
                </div>
                <div className="flex flex-wrap items-center gap-3">
                    <Button
                        type="submit"
                        className="h-11"
                        disabled={form.processing}
                    >
                        {form.processing && <Spinner />}
                        Tes &amp; simpan
                    </Button>
                    <Button
                        type="button"
                        variant="outline"
                        className="h-11"
                        onClick={onDone}
                    >
                        Batal
                    </Button>
                    <span className="text-[13px] text-muted-foreground">
                        Lumi mengirim satu permintaan kecil untuk mengecek key
                        sebelum menyimpan.
                    </span>
                </div>
            </form>
        </section>
    );
}

function ProviderCard({ provider }: { provider: Provider }) {
    const [changingKey, setChangingKey] = useState(false);
    const [testing, setTesting] = useState(false);
    const keyForm = useForm({ api_key: '' });
    const modelForm = useForm({ model_id: '', label: '' });

    const test = () =>
        router.visit(testProvider(provider.id), {
            preserveScroll: true,
            onStart: () => setTesting(true),
            onFinish: () => setTesting(false),
        });

    const saveKey = (e: React.FormEvent) => {
        e.preventDefault();
        keyForm.submit(updateKey(provider.id), {
            preserveScroll: true,
            onSuccess: () => setChangingKey(false),
            onFinish: () => keyForm.reset('api_key'),
        });
    };

    const addModel = (e: React.FormEvent) => {
        e.preventDefault();
        modelForm.submit(storeModel(provider.id), {
            preserveScroll: true,
            onSuccess: () => modelForm.reset(),
        });
    };

    const remove = () => {
        if (window.confirm(`Hapus ${provider.name} beserta semua modelnya?`)) {
            router.visit(destroyProvider(provider.id), {
                preserveScroll: true,
            });
        }
    };

    return (
        <section
            aria-labelledby={`provider-${provider.id}`}
            className="flex flex-col gap-4 rounded-2xl border bg-card p-5"
        >
            <div className="flex flex-wrap items-center gap-3.5">
                <div className="flex flex-[1_1_260px] flex-col gap-1.5">
                    <div className="flex flex-wrap items-center gap-2.5">
                        <h2
                            id={`provider-${provider.id}`}
                            className="font-display text-[19px] font-semibold"
                        >
                            {provider.name}
                        </h2>
                        {provider.is_enabled ? (
                            <Pill tone="lime">Aktif</Pill>
                        ) : (
                            <Pill tone="plain">Nonaktif</Pill>
                        )}
                    </div>
                    <p className="text-[13px] text-muted-foreground">
                        {provider.base_url ?? 'openrouter.ai'} · key{' '}
                        <span className="font-mono text-foreground/80">
                            •••• {provider.key_last4}
                        </span>
                        {' · '}
                        {provider.last_tested_at ? (
                            <span
                                className={
                                    provider.last_error
                                        ? 'text-lumi-amber'
                                        : undefined
                                }
                            >
                                tes terakhir{' '}
                                {provider.last_error
                                    ? `gagal (${provider.last_error})`
                                    : 'berhasil'}{' '}
                                {shortTime(provider.last_tested_at)}
                            </span>
                        ) : (
                            'belum pernah dites'
                        )}
                    </p>
                </div>
                <div className="flex flex-wrap gap-2">
                    <Button
                        type="button"
                        variant="outline"
                        onClick={test}
                        disabled={testing}
                    >
                        {testing && <Spinner />}
                        Tes koneksi
                    </Button>
                    <Button
                        type="button"
                        variant="outline"
                        aria-expanded={changingKey}
                        onClick={() => setChangingKey(!changingKey)}
                    >
                        Ganti key
                    </Button>
                    <Button
                        type="button"
                        variant="outline"
                        onClick={() =>
                            router.visit(updateProvider(provider.id), {
                                data: { is_enabled: !provider.is_enabled },
                                preserveScroll: true,
                            })
                        }
                    >
                        {provider.is_enabled ? 'Nonaktifkan' : 'Aktifkan'}
                    </Button>
                    <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        aria-label={`Hapus ${provider.name}`}
                        onClick={remove}
                    >
                        <Trash2 aria-hidden="true" />
                    </Button>
                </div>
            </div>

            {changingKey && (
                <form
                    onSubmit={saveKey}
                    className="flex flex-wrap items-end gap-2.5"
                >
                    <div className="flex flex-[1_1_280px] flex-col gap-1.5">
                        <Label
                            htmlFor={`key-${provider.id}`}
                            className="text-xs text-muted-foreground"
                        >
                            API key baru
                        </Label>
                        <Input
                            id={`key-${provider.id}`}
                            type="password"
                            autoComplete="off"
                            value={keyForm.data.api_key}
                            onChange={(e) =>
                                keyForm.setData('api_key', e.target.value)
                            }
                            className="h-10"
                            required
                        />
                        <InputError message={keyForm.errors.api_key} />
                    </div>
                    <Button type="submit" disabled={keyForm.processing}>
                        {keyForm.processing && <Spinner />}
                        Tes &amp; simpan key
                    </Button>
                </form>
            )}

            <div className="overflow-x-auto rounded-xl border">
                <table className="w-full min-w-[640px] border-collapse text-[13px]">
                    <caption className="px-3.5 py-3 text-left text-[13px] font-semibold text-foreground/80">
                        Model
                    </caption>
                    <thead>
                        <tr className="text-left text-muted-foreground">
                            <Th className="border-t px-3.5">Label</Th>
                            <Th className="border-t px-3.5">ID model</Th>
                            <Th className="border-t px-3.5">Default</Th>
                            <Th className="border-t px-3.5">Aktif</Th>
                            <Th className="border-t px-3.5">
                                <span className="sr-only">Hapus</span>
                            </Th>
                        </tr>
                    </thead>
                    <tbody>
                        {provider.models.map((m) => (
                            <tr
                                key={m.id}
                                className="border-b border-border/70 last:border-0"
                            >
                                <td className="px-3.5 py-2.5 font-medium">
                                    {m.label}
                                </td>
                                <td className="px-3.5 py-2.5 font-mono text-foreground/80">
                                    {m.model_id}
                                </td>
                                <td className="px-3.5 py-2.5">
                                    <button
                                        type="button"
                                        aria-pressed={m.is_default}
                                        aria-label={
                                            m.is_default
                                                ? `${m.label} adalah model default`
                                                : `Jadikan ${m.label} model default`
                                        }
                                        disabled={m.is_default}
                                        onClick={() =>
                                            router.visit(makeDefault(m.id), {
                                                preserveScroll: true,
                                            })
                                        }
                                        className={
                                            m.is_default
                                                ? 'min-h-9 rounded-full border border-primary bg-accent px-3 text-xs font-semibold text-accent-foreground'
                                                : 'min-h-9 rounded-full border border-input px-3 text-xs font-semibold text-foreground/80 hover:bg-muted'
                                        }
                                    >
                                        {m.is_default
                                            ? 'Default'
                                            : 'Jadikan default'}
                                    </button>
                                </td>
                                <td className="px-3.5 py-2.5">
                                    <SwitchButton
                                        checked={m.is_enabled}
                                        label={`${m.label} aktif`}
                                        disabled={m.is_default}
                                        onChange={(on) =>
                                            router.visit(updateModel(m.id), {
                                                data: { is_enabled: on },
                                                preserveScroll: true,
                                            })
                                        }
                                    />
                                </td>
                                <td className="px-3.5 py-2.5 text-right">
                                    {!m.is_default && (
                                        <Button
                                            type="button"
                                            variant="ghost"
                                            size="icon"
                                            aria-label={`Hapus model ${m.label}`}
                                            onClick={() =>
                                                router.visit(
                                                    destroyModel(m.id),
                                                    { preserveScroll: true },
                                                )
                                            }
                                        >
                                            <Trash2 aria-hidden="true" />
                                        </Button>
                                    )}
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            <form
                onSubmit={addModel}
                className="flex flex-wrap items-end gap-2.5"
            >
                <div className="flex flex-[2_1_280px] flex-col gap-1.5">
                    <Label
                        htmlFor={`m-id-${provider.id}`}
                        className="text-xs text-muted-foreground"
                    >
                        ID model baru
                    </Label>
                    <Input
                        id={`m-id-${provider.id}`}
                        value={modelForm.data.model_id}
                        onChange={(e) =>
                            modelForm.setData('model_id', e.target.value)
                        }
                        placeholder="contoh: nvidia/nemotron-3.5-lightning:free"
                        className="h-10 font-mono"
                        required
                    />
                    <InputError message={modelForm.errors.model_id} />
                </div>
                <div className="flex flex-[1_1_180px] flex-col gap-1.5">
                    <Label
                        htmlFor={`m-label-${provider.id}`}
                        className="text-xs text-muted-foreground"
                    >
                        Label
                    </Label>
                    <Input
                        id={`m-label-${provider.id}`}
                        value={modelForm.data.label}
                        onChange={(e) =>
                            modelForm.setData('label', e.target.value)
                        }
                        className="h-10"
                    />
                </div>
                <Button
                    type="submit"
                    variant="outline"
                    disabled={modelForm.processing}
                >
                    {modelForm.processing && <Spinner />}
                    Tes &amp; tambah
                </Button>
            </form>
        </section>
    );
}

function Field({
    label,
    id,
    error,
    children,
}: {
    label: string;
    id: string;
    error?: string;
    children: React.ReactNode;
}) {
    return (
        <div className="flex flex-col gap-2">
            <Label htmlFor={id} className="text-[13px] text-muted-foreground">
                {label}
            </Label>
            {children}
            <InputError message={error} />
        </div>
    );
}

Providers.layout = {
    breadcrumbs: [{ title: 'Provider & model', href: providersIndex() }],
};

import { Head, router, useForm } from '@inertiajs/react';
import { useState } from 'react';
import { SwitchButton } from '@/components/console/switch-button';
import { Pill, Th } from '@/components/console/table';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import {
    index as toolsIndex,
    update as updatePolicy,
} from '@/routes/console/tools';
import {
    test as testWebSearch,
    update as updateWebSearch,
} from '@/routes/console/tools/web-search';

type Mode = 'auto' | 'ask' | 'disabled';

type ToolRow = {
    name: string;
    label: string;
    description: string;
    available: boolean;
    user_mode: Mode;
    superadmin_mode: Mode;
    default_user_mode: Mode;
    default_superadmin_mode: Mode;
};

type WebSearchConfig = {
    enabled: boolean;
    driver: 'tavily' | 'brave';
    has_key: boolean;
    key_last4: string | null;
};

type Props = {
    tools: ToolRow[];
    webSearch: WebSearchConfig;
};

const selectClass =
    'h-[38px] rounded-[10px] border border-input bg-background px-3 text-sm';

export default function ToolsPage({ tools, webSearch }: Props) {
    const [savingTool, setSavingTool] = useState<string | null>(null);
    const [testingSearch, setTestingSearch] = useState(false);

    const searchForm = useForm({
        enabled: webSearch.enabled,
        driver: webSearch.driver,
        api_key: '',
        clear_key: false,
    });

    const changePolicy = (
        tool: ToolRow,
        role: 'user' | 'superadmin',
        mode: Mode,
    ) => {
        setSavingTool(tool.name);
        router.put(
            updatePolicy.url(tool.name),
            {
                user_mode: role === 'user' ? mode : tool.user_mode,
                superadmin_mode:
                    role === 'superadmin' ? mode : tool.superadmin_mode,
            },
            {
                preserveScroll: true,
                onFinish: () => setSavingTool(null),
            },
        );
    };

    const submitWebSearch = (e: React.FormEvent) => {
        e.preventDefault();
        searchForm.submit(updateWebSearch(), {
            preserveScroll: true,
            onSuccess: () => {
                searchForm.setData('api_key', '');
                searchForm.setData('clear_key', false);
            },
        });
    };

    const handleTestWebSearch = () => {
        setTestingSearch(true);
        router.post(
            testWebSearch.url(),
            {
                driver: searchForm.data.driver,
                api_key: searchForm.data.api_key || null,
            },
            {
                preserveScroll: true,
                onFinish: () => setTestingSearch(false),
            },
        );
    };

    const handleClearKey = () => {
        router.put(
            updateWebSearch.url(),
            {
                enabled: false,
                driver: searchForm.data.driver,
                clear_key: true,
            },
            {
                preserveScroll: true,
                onSuccess: () => {
                    searchForm.setData({
                        enabled: false,
                        driver: searchForm.data.driver,
                        api_key: '',
                        clear_key: false,
                    });
                },
            },
        );
    };

    return (
        <>
            <Head title="Tools & izin" />
            <div className="flex flex-col gap-6 p-4 md:p-8">
                <header className="flex flex-col gap-1.5">
                    <h1 className="font-display text-[28px] font-semibold">
                        Tools &amp; izin
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Atur kemampuan agent per role. Izin selalu ditegakkan di
                        server — prompt user tidak bisa melewatinya.
                    </p>
                </header>

                <section
                    aria-label="Daftar tool agent"
                    className="overflow-hidden rounded-2xl border bg-card"
                >
                    <div className="overflow-x-auto">
                        <table className="w-full min-w-[780px] border-collapse text-[13px]">
                            <thead>
                                <tr className="text-left text-muted-foreground">
                                    <Th className="px-4">Tool</Th>
                                    <Th className="px-4">Status</Th>
                                    <Th className="px-4">Role User</Th>
                                    <Th className="px-4">Role Superadmin</Th>
                                </tr>
                            </thead>
                            <tbody>
                                {tools.map((tool) => {
                                    const busy = savingTool === tool.name;
                                    const active =
                                        tool.available &&
                                        (tool.user_mode !== 'disabled' ||
                                            tool.superadmin_mode !==
                                                'disabled');

                                    return (
                                        <tr
                                            key={tool.name}
                                            className="border-b border-border/70 last:border-b-0"
                                        >
                                            <td className="px-4 py-3.5 align-top">
                                                <div className="flex flex-col gap-0.5">
                                                    <div className="flex items-center gap-2">
                                                        <span className="text-sm font-medium text-foreground">
                                                            {tool.label}
                                                        </span>
                                                        <span className="font-mono text-xs text-muted-foreground">
                                                            {tool.name}
                                                        </span>
                                                    </div>
                                                    <span className="text-xs text-muted-foreground">
                                                        {tool.description}
                                                    </span>
                                                </div>
                                            </td>
                                            <td className="px-4 py-3.5 align-middle">
                                                {!tool.available ? (
                                                    <Pill tone="amber">
                                                        Perlu konfigurasi
                                                    </Pill>
                                                ) : active ? (
                                                    <Pill tone="lime">
                                                        Aktif
                                                    </Pill>
                                                ) : (
                                                    <Pill tone="plain">
                                                        Nonaktif
                                                    </Pill>
                                                )}
                                            </td>
                                            <td className="px-4 py-3.5 align-middle">
                                                <select
                                                    aria-label={`Mode ${tool.name} untuk user`}
                                                    value={tool.user_mode}
                                                    disabled={busy}
                                                    onChange={(e) =>
                                                        changePolicy(
                                                            tool,
                                                            'user',
                                                            e.target
                                                                .value as Mode,
                                                        )
                                                    }
                                                    className={selectClass}
                                                >
                                                    <option value="auto">
                                                        Otomatis (auto)
                                                    </option>
                                                    <option value="ask">
                                                        Minta izin (ask)
                                                    </option>
                                                    <option value="disabled">
                                                        Nonaktif
                                                    </option>
                                                </select>
                                            </td>
                                            <td className="px-4 py-3.5 align-middle">
                                                <select
                                                    aria-label={`Mode ${tool.name} untuk superadmin`}
                                                    value={tool.superadmin_mode}
                                                    disabled={busy}
                                                    onChange={(e) =>
                                                        changePolicy(
                                                            tool,
                                                            'superadmin',
                                                            e.target
                                                                .value as Mode,
                                                        )
                                                    }
                                                    className={selectClass}
                                                >
                                                    <option value="auto">
                                                        Otomatis (auto)
                                                    </option>
                                                    <option value="ask">
                                                        Minta izin (ask)
                                                    </option>
                                                    <option value="disabled">
                                                        Nonaktif
                                                    </option>
                                                </select>
                                            </td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    </div>
                </section>

                <form
                    onSubmit={submitWebSearch}
                    className="flex max-w-[760px] flex-col gap-4 rounded-2xl border bg-card p-5"
                >
                    <div className="flex items-start justify-between gap-4">
                        <div className="flex flex-col gap-1">
                            <h2
                                id="ws-label"
                                className="font-display text-[17px] font-semibold"
                            >
                                Web Search (Opsional)
                            </h2>
                            <p className="text-[13px] text-muted-foreground">
                                Izinkan Lumi mencari informasi terbaru via
                                Tavily atau Brave Search. API key disimpan
                                terenkripsi dan tidak pernah ditampilkan lagi.
                            </p>
                        </div>
                        <SwitchButton
                            checked={searchForm.data.enabled}
                            onChange={(v) => searchForm.setData('enabled', v)}
                            labelledBy="ws-label"
                        />
                    </div>

                    <div className="grid gap-4 sm:grid-cols-2">
                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="ws-driver" className="text-sm">
                                Provider pencarian
                            </Label>
                            <select
                                id="ws-driver"
                                value={searchForm.data.driver}
                                onChange={(e) =>
                                    searchForm.setData(
                                        'driver',
                                        e.target.value as 'tavily' | 'brave',
                                    )
                                }
                                className="h-11 rounded-[10px] border border-input bg-background px-3 text-sm"
                            >
                                <option value="tavily">Tavily</option>
                                <option value="brave">Brave Search</option>
                            </select>
                            <InputError message={searchForm.errors.driver} />
                        </div>

                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="ws-key" className="text-sm">
                                API key
                            </Label>
                            <Input
                                id="ws-key"
                                type="password"
                                autoComplete="off"
                                value={searchForm.data.api_key}
                                placeholder={
                                    webSearch.has_key
                                        ? `Tersimpan (••••${webSearch.key_last4})`
                                        : 'Masukkan API key'
                                }
                                onChange={(e) =>
                                    searchForm.setData(
                                        'api_key',
                                        e.target.value,
                                    )
                                }
                                className="h-11"
                            />
                            <InputError message={searchForm.errors.api_key} />
                        </div>
                    </div>

                    <div className="flex flex-wrap items-center gap-2.5 pt-1">
                        <Button
                            type="submit"
                            className="h-10 px-4"
                            disabled={searchForm.processing}
                        >
                            {searchForm.processing && <Spinner />}
                            Simpan Web Search
                        </Button>
                        <Button
                            type="button"
                            variant="outline"
                            className="h-10 px-4"
                            disabled={
                                testingSearch ||
                                (!webSearch.has_key &&
                                    searchForm.data.api_key.trim() === '')
                            }
                            onClick={handleTestWebSearch}
                        >
                            {testingSearch && <Spinner />}
                            Uji koneksi
                        </Button>
                        {webSearch.has_key && (
                            <Button
                                type="button"
                                variant="ghost"
                                className="h-10 px-3 text-lumi-coral hover:text-lumi-coral"
                                onClick={handleClearKey}
                            >
                                Hapus key
                            </Button>
                        )}
                    </div>
                </form>
            </div>
        </>
    );
}

ToolsPage.layout = {
    breadcrumbs: [{ title: 'Tools & izin', href: toolsIndex() }],
};

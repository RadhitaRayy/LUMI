import { LumiCat, LumiWordmark } from '@/components/lumi-cat';
import type { AuthLayoutProps } from '@/types';

export default function AuthSimpleLayout({
    children,
    title,
    description,
}: AuthLayoutProps) {
    return (
        <div className="flex min-h-svh flex-col items-center justify-center bg-background px-4 py-12">
            <main className="flex w-full max-w-[420px] flex-col gap-7">
                <div className="flex items-center gap-4">
                    <LumiCat className="size-24 shrink-0" />
                    <div className="flex flex-col gap-1">
                        <LumiWordmark className="text-5xl text-foreground" />
                        <span className="text-xs font-semibold tracking-[0.1em] text-muted-foreground">
                            CONSOLE
                        </span>
                    </div>
                </div>

                <section className="flex flex-col gap-6 rounded-[20px] border bg-card p-7">
                    <div className="flex flex-col gap-2">
                        <h1 className="font-display text-[26px] leading-tight font-semibold">
                            {title}
                        </h1>
                        {description && (
                            <p className="text-sm leading-relaxed text-muted-foreground">
                                {description}
                            </p>
                        )}
                    </div>
                    {children}
                </section>
            </main>
        </div>
    );
}

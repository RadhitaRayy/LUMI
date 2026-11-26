import { LumiCat, LumiWordmark } from '@/components/lumi-cat';
import type { AuthLayoutProps } from '@/types';

export default function AuthSimpleLayout({
    children,
    title,
    description,
}: AuthLayoutProps) {
    return (
        <div className="flex min-h-svh flex-col items-center justify-center bg-background px-4 py-8">
            <main className="flex w-full max-w-[400px] flex-col gap-5">
                <div className="flex items-center gap-3">
                    <LumiCat className="size-16 shrink-0" />
                    <div className="flex flex-col gap-1">
                        <LumiWordmark className="text-4xl text-foreground" />
                        <span className="text-[11px] font-semibold tracking-[0.1em] text-muted-foreground">
                            CONSOLE
                        </span>
                    </div>
                </div>

                <section className="flex flex-col gap-5 rounded-[20px] border bg-card p-6">
                    <div className="flex flex-col gap-1.5">
                        <h1 className="font-display text-2xl leading-tight font-semibold">
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

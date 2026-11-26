import { LumiCatIcon, LumiWordmark } from '@/components/lumi-cat';

export default function AppLogo() {
    return (
        <>
            <LumiCatIcon className="size-8 shrink-0" />
            <div className="ml-1 flex flex-1 items-baseline gap-2 overflow-hidden">
                <LumiWordmark className="text-[22px] text-sidebar-foreground" />
                <span className="pb-0.5 text-[10px] font-semibold tracking-[0.1em] text-muted-foreground">
                    CONSOLE
                </span>
            </div>
        </>
    );
}

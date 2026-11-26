import { LumiCatIcon, LumiWordmark } from '@/components/lumi-cat';

export default function AppLogo() {
    return (
        <>
            {/* Wrapped so the sidebar button's `[&>svg]:size-4` rule cannot shrink it. */}
            <span className="flex size-8 shrink-0">
                <LumiCatIcon className="size-full" />
            </span>
            {/* Only the cat shows when the sidebar is collapsed to icons. */}
            <div className="ml-1 flex flex-1 items-baseline gap-2 overflow-hidden group-data-[collapsible=icon]:hidden">
                <LumiWordmark className="text-[22px] text-sidebar-foreground" />
                <span className="pb-0.5 text-[10px] font-semibold tracking-[0.1em] text-muted-foreground">
                    CONSOLE
                </span>
            </div>
        </>
    );
}

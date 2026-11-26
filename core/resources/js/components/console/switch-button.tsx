import { cn } from '@/lib/utils';

type Props = {
    checked: boolean;
    onChange: (checked: boolean) => void;
    label?: string;
    labelledBy?: string;
    disabled?: boolean;
};

/** An on/off switch (role="switch"), lime when on. */
export function SwitchButton({
    checked,
    onChange,
    label,
    labelledBy,
    disabled,
}: Props) {
    return (
        <button
            type="button"
            role="switch"
            aria-checked={checked}
            aria-label={label}
            aria-labelledby={labelledBy}
            disabled={disabled}
            onClick={() => onChange(!checked)}
            className={cn(
                'flex h-[30px] w-[52px] shrink-0 items-center rounded-full p-[3px] transition-colors focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background focus-visible:outline-none disabled:opacity-50',
                checked ? 'justify-end bg-primary' : 'justify-start bg-input',
            )}
        >
            <span
                aria-hidden="true"
                className={cn(
                    'size-6 rounded-full transition-colors',
                    checked ? 'bg-primary-foreground' : 'bg-muted-foreground',
                )}
            />
        </button>
    );
}

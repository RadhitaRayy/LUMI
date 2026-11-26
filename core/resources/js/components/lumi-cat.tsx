import type { SVGAttributes } from 'react';

/**
 * Lumi's character: an orange kampung cat carrying a lime paper lantern, drawn as a sticker.
 * Source: design/brand/lumi-cat.svg. Each component namespaces its <defs> ids.
 */

function CatBody() {
    return (
        <>
            <path
                d="M74 200 C 35 205 18 165 40 140 C 44 136 50 140 47 145 C 32 165 42 190 74 188 Z"
                fill="#F2A65A"
            />
            <ellipse cx="120" cy="172" rx="52" ry="46" fill="#F2A65A" />
            <ellipse cx="120" cy="180" rx="28" ry="28" fill="#FBE3C8" />
            <ellipse cx="100" cy="214" rx="16" ry="9" fill="#F2A65A" />
            <ellipse cx="140" cy="214" rx="16" ry="9" fill="#F2A65A" />
            <path d="M80 82 L86 44 L110 66 Z" fill="#F2A65A" />
            <path d="M160 82 L154 44 L130 66 Z" fill="#F2A65A" />
            <ellipse cx="120" cy="106" rx="50" ry="42" fill="#F2A65A" />
            <path d="M90 60 L92 72 L102 68 Z" fill="#F7C6B5" stroke="none" />
            <path d="M150 60 L148 72 L138 68 Z" fill="#F7C6B5" stroke="none" />
            <path d="M110 68 L112 80 M120 66 V80 M130 68 L128 80" fill="none" />
            <ellipse cx="102" cy="106" rx="5" ry="7" fill="#14161A" />
            <ellipse cx="138" cy="106" rx="5" ry="7" fill="#14161A" />
            <ellipse
                cx="90"
                cy="120"
                rx="7"
                ry="4"
                fill="#F7C6B5"
                stroke="none"
            />
            <ellipse
                cx="150"
                cy="120"
                rx="7"
                ry="4"
                fill="#F7C6B5"
                stroke="none"
            />
            <path d="M116 116 L124 116 L120 121 Z" fill="#E07A6A" />
            <path
                d="M120 121 Q115 128 109 124 M120 121 Q125 128 131 124"
                fill="none"
            />
            <path
                d="M76 110 L60 106 M76 116 L60 118 M164 110 L180 106 M164 116 L180 118"
                fill="none"
            />
        </>
    );
}

function CatPaw() {
    return (
        <ellipse
            cx="172"
            cy="136"
            rx="12"
            ry="24"
            fill="#F2A65A"
            transform="rotate(28 172 136)"
        />
    );
}

function CatLantern() {
    return (
        <>
            <path d="M42 140 V156" fill="none" />
            <rect x="34" y="153" width="16" height="6" rx="2" fill="#3A4150" />
            <ellipse cx="42" cy="174" rx="15" ry="17" fill="#B5F23D" />
            <path
                d="M42 157 V191 M34 160 Q30 174 34 188 M50 160 Q54 174 50 188"
                fill="none"
            />
            <rect x="35" y="189" width="14" height="5" rx="2" fill="#3A4150" />
        </>
    );
}

const OUTLINE = { stroke: '#F2EEE3', strokeWidth: 14 };
const INK = { stroke: '#14161A', strokeWidth: 3.5 };

/** The whole character, waving (motion is off for people who ask for reduced motion). */
export function LumiCat({
    animated = true,
    ...props
}: SVGAttributes<SVGElement> & { animated?: boolean }) {
    return (
        <svg
            viewBox="0 0 240 240"
            role="img"
            aria-label="Lumi, kucing oranye yang melambai sambil membawa lentera hijau"
            {...props}
        >
            <g
                strokeLinecap="round"
                strokeLinejoin="round"
                className={animated ? 'lumi-cat-bob' : undefined}
            >
                <g className={animated ? 'lumi-cat-swing' : undefined}>
                    <g {...OUTLINE}>
                        <CatLantern />
                    </g>
                    <g {...INK}>
                        <CatLantern />
                    </g>
                </g>
                <g {...OUTLINE}>
                    <CatBody />
                </g>
                <g className={animated ? 'lumi-cat-wave' : undefined}>
                    <g {...OUTLINE}>
                        <CatPaw />
                    </g>
                    <g {...INK}>
                        <CatPaw />
                    </g>
                </g>
                <g {...INK}>
                    <CatBody />
                </g>
            </g>
        </svg>
    );
}

/** The cat's head on a lime tile: app icon, favicon, sidebar mark. */
export function LumiCatIcon(props: SVGAttributes<SVGElement>) {
    return (
        <svg viewBox="0 0 120 120" aria-hidden="true" {...props}>
            <rect width="120" height="120" rx="28" fill="#B5F23D" />
            <svg x="2" y="8" width="116" height="116" viewBox="62 36 116 116">
                <g
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    stroke="#14161A"
                    strokeWidth={4}
                >
                    <CatBody />
                </g>
            </svg>
        </svg>
    );
}

/** "lumi" in Bricolage Grotesque with a lime square for the dot of the i. */
export function LumiWordmark({ className = '' }: { className?: string }) {
    return (
        <span
            className={`inline-flex items-baseline font-logo leading-none font-extrabold tracking-[-0.05em] ${className}`}
            aria-label="lumi"
            role="img"
        >
            <span aria-hidden="true">lum</span>
            <span aria-hidden="true" className="relative inline-block">
                ı
                <span className="absolute top-[0.02em] left-1/2 size-[0.17em] -translate-x-[46%] rounded-[0.03em] bg-lumi-lime" />
            </span>
        </span>
    );
}

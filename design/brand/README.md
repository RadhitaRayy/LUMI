# Lumi brand

Decided 2026-11-26: **character K1 (cat with a lantern)** + **wordmark A (geometric)**.
The design sources and the concepts that weren't picked are on the Lumi Console canvas (`design/console/`).

## Character

- **Lumi, the cat with a lantern**: an orange kampung cat in sticker style (thick ink outlines,
  flat colours, a cream border). The lime paper lantern on its tail is Lumi's signature colour.
- No glow, gradients or sparkles.
- `lumi-cat.svg`: the full character (sign-in screen, empty states, stickers).
- `lumi-icon.svg`: the app icon, the cat's head on a lime tile (also the Console favicon).
- `lumi-icon-foreground.svg`: the foreground layer of the Android adaptive icon (background `#B5F23D`).
- The app draws the cat in code (`app/lib/widgets/lumi_cat.dart`) so the lantern, paw and eyes can
  animate; its launcher icons are rendered from these SVGs into `app/assets/icon/`.

## Wordmark

- `lumi` in lower case, **Bricolage Grotesque 800**, letter spacing -0.05em.
- The dot of the i is a small lime square `#B5F23D` (on light backgrounds: `#6C9A12`).
- In the Console: the wordmark + a `CONSOLE` label (Inter 600, upper case, 0.1em spacing).

## Colours

| Name | Hex |
|---|---|
| Background | `#0E1014` |
| Surface | `#13161B` / `#171A20` |
| Line | `#23272F` / `#2A2F38` |
| Text | `#ECEEF1` |
| Muted text | `#9BA3AF` |
| Lime (accent) | `#B5F23D` |
| Amber (warning) | `#F5B544` |
| Coral (destructive) | `#FFA899` |
| Cat orange | `#F2A65A` |
| Ink | `#14161A` |

## Type

Inter (body), Space Grotesk (headings), JetBrains Mono (code/numbers), Bricolage Grotesque (wordmark).

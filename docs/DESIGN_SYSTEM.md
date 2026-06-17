# JCAI Design System — "Friendly Focus"

Warm, student-friendly study tool for SG JC A-Level students — approachable and
rounded, but credible (not childish). Light-primary with a first-class true dark
mode (students study at night). This file is the source of truth; the Flutter
`ThemeData` derives directly from these tokens.

Audience is 16–18, high-stakes exam prep, hours of use. Friendly and warm, but it
must read as a serious tool that helps them score — never toy-like.

> Direction chosen 2026-06-17: rounded/bubbly + light purple. (Earlier teal +
> serif "Quiet Focus" alternative retired; revert reference if ever needed.)

## Typography
- **Display / headings:** Baloo 2 — rounded, warm, friendly; screen titles,
  concept headings, large numerals. Weights 500/600/700.
- **UI / body:** Nunito — rounded terminals, highly readable, friendly-but-mature.
  Weights 400/500/600/700.
- **Working / code:** IBM Plex Mono — inline steps, code. (LaTeX via flutter_math.)

Type scale (pt) · line-height:
| Token | Size | LH | Font | Use |
|---|---|---|---|---|
| display | 36 | 1.1 | Baloo 2 600 | hero / large titles |
| title-lg | 24 | 1.2 | Baloo 2 600 | screen titles, concept headings |
| title | 20 | 1.3 | Baloo 2 600 | section headings |
| body-lg | 18 | 1.55 | Nunito 500 | tutor answer body |
| body | 16 | 1.55 | Nunito 400/500 | default body (base) |
| label | 14 | 1.4 | Nunito 600/700 | buttons, chips, labels |
| caption | 12.5 | 1.4 | Nunito 600 | citations, meta |
| mono | 15 | 1.5 | IBM Plex Mono | inline working |

Rules: base 16pt; honor Dynamic Type (scale, no truncation); measure 60–75 chars
desktop / 35–60 mobile; tabular figures for any numeric columns. Body text often
sits at weight 500 (Nunito 400 can read light) — pick per contrast.

## Color — Light (soft lavender paper)
| Token | Hex | Notes |
|---|---|---|
| background | #FAF8FF | faint lavender paper |
| surface | #FFFFFF | cards, sheets |
| surface-muted | #F1EEFA | input fields, recessed, neutral chips |
| foreground | #221F33 | deep plum-ink (high contrast on bg) |
| foreground-muted | #6F6A82 | secondary text (≥4.5:1) |
| border | #E9E4F6 | hairline |
| primary | #6B5DE0 | light-purple accent / fill (white text passes here) |
| primary-strong | #5B4FCF | links, emphasis text on light |
| on-primary | #FFFFFF | on the #6B5DE0 fill |
| primary-soft | #EEEBFC | tinted chip/badge/bubble bg |
| on-primary-soft | #4A3D9E | text on primary-soft |
| success | #15803D | correct |
| warning | #B45309 | check / caution |
| danger | #DC2626 | wrong / destructive |

## Color — Dark (lavender on slate)
| Token | Hex | Notes |
|---|---|---|
| background | #121017 | slate with a faint purple cast (not pure black) |
| surface | #1A1823 | cards |
| surface-muted | #221F2E | input fields |
| foreground | #ECEAF2 | soft white |
| foreground-muted | #9D98AC | secondary (≥4.5:1 on bg) |
| border | #2C2A38 | hairline (~rgba 255/0.09) |
| primary | #A99BF5 | soft lavender for dark accents/links |
| on-primary | #1A1430 | dark ink on lavender fill |
| primary-soft | #2A2440 | tinted badge/bubble bg |
| on-primary-soft | #C9BEFA | text on primary-soft |
| success | #4ADE80 |  |
| warning | #FBBF24 |  |
| danger | #F87171 |  |

Both themes are designed together and contrast-tested independently (AA: 4.5:1
text, 3:1 large/icons). Semantic colors always pair with an icon/text, never
color alone.

## Spacing — 4pt base
`2 · 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64`. Section rhythm tiers 16/24/32.
Screen gutters: 20 phone, 32 tablet. Comfortable touch density (no cramping).

## Radius
cards 16 · buttons 12 · inputs 12 · chips/pills 999 (full) · bottom sheets 24 (top) ·
message bubbles 18 (with one squared corner toward the speaker).

## Elevation
- **Light:** soft, low. `e1 = 0 1px 2px rgba(28,27,25,.04)`, `e2 = 0 4px 16px rgba(28,27,25,.06)`, `e3 (sheets) = 0 12px 32px rgba(28,27,25,.10)`.
- **Dark:** elevation via surface lightness + hairline border; shadow minimal. Faint accent glow allowed *only* behind the primary CTA.

## Motion
Durations: micro 150ms · standard 200ms · enter 260ms · exit ~70% of enter.
Easing: enter `cubic-bezier(0.2,0,0,1)` (ease-out), exit ease-in; spring for press
(scale 0.97→1). One orchestrated staggered reveal on screen load (30–50ms/item).
Streamed tokens fade in. **Respect reduced-motion** (cut to fades/instant).
Never block input during animation; animations interruptible.

## Iconography
One family: **Phosphor** (rounded, friendly, consistent stroke — fits the warm
direction). Sizes 20 / 24. Stroke weight consistent per layer. Vector only —
never emoji. Touch ≥44pt (use hit-area expansion for 20–24pt glyphs).
**No "sparkles" / ✨ motif anywhere** — it reads as default-AI design. The brand
mark is a custom monogram/logo (generated asset), not a sparkle.

## Brand mark & illustration
- **Logo:** a friendly custom mark (generated), NOT sparkles/robot/lightbulb/
  graduation-cap clichés. Works as a small app-icon tile and inline wordmark.
- **Onboarding is illustration-led**, by deliberate generated image assets — not
  text-heavy UI panels. Each onboarding screen: one warm hero illustration +
  minimal copy + one action. Illustration style is a single cohesive set in the
  lavender/purple palette: rounded, warm, characterful — and intentional, NOT
  generic "corporate-memphis blob people" or sloppy AI-stock look. The illustration
  set is a defined asset deliverable (see frontend plan).

## Components (tokens applied)
- **Buttons:** primary (teal fill, on-primary text, e1), secondary (surface + border),
  ghost (text + teal on hover/press). Height 48; radius 12; press scale 0.97; loading = spinner, disabled = 0.4 opacity.
- **Message bubbles:** student (primary-soft, right), tutor (surface, left), radius 18.
  Tutor answers use Fraunces concept headings + Lexend body + inline `[#n]` citation chips.
- **Citation chip:** caption, primary-soft bg, full radius, tap → source sheet.
- **Mode badge:** small pill — "Teaching" (neutral) / "Exam answer" (teal). Auto-set.
- **Answer-style toggle:** segmented "Guide me / Just answer" in the input bar.
- **Input bar:** surface-muted field, image button (Phosphor camera), send (teal),
  safe-area aware, grows to ~5 lines.
- **Nav:** phone = bottom bar (Home · Chat · History · Profile, ≤5, icon+label,
  active highlighted); tablet ≥768 = nav rail + two-pane (list ‖ chat).
- **States:** skeleton shimmer (>300ms), empty (illustration + one action),
  error/429/503/offline (clear cause + recovery), toast (aria-live, 3–5s).

## Responsive
Breakpoints 360 / 430 / 768 / 1024. Mobile-first; min-h-dvh; safe areas for
notch/Dynamic Island/gesture bar + fixed bars; landscape readable; tablet shifts
chat to two-pane and widens gutters; long-form text capped measure on tablet.

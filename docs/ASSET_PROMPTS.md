# Lactic Onboarding & App Illustration — Prompt Pack

Generated image assets for the **Friendly Focus** direction (light-purple +
Baloo 2/Nunito). Onboarding is illustration-led: one warm hero per screen,
minimal copy, one action.

**The single most important rule:** every prompt starts with the *same* STYLE
BLOCK below, verbatim. Consistency across the set is what makes it look
intentional instead of "AI generated."

**Generate ONE asset per run — never all of them in a single prompt** (the model
will collage them or weaken composition/aspect ratio). Run each prompt separately
in the same session, keep the style sentence identical, and (if your model
supports it) reuse one seed / style-reference across all of them. Pick the most
cohesive set; regenerate outliers, don't mix styles. The app icon is generated
separately with its own stricter icon-only prompt (below).

---

## STYLE BLOCK (prepend to every illustration prompt)

> Modern flat illustration with soft depth, for a warm but premium study app.
> Rounded, chunky geometric shapes; clean confident forms; consistent line
> weight. Limited palette: soft lavender-purple (#6B5DE0), a gentle coral/peach
> accent (#F0907A), cream background (#FAF8FF), deep plum ink (#221F33), with a
> calm sage-green only for "correct/check" touches. Subtle soft shadows, faint
> paper grain. Mood: warm, calm, encouraging, studious, capable. Generous
> negative space, a single clear focal subject, balanced composition. Portrait
> orientation for a mobile screen.
>
> Negative / avoid: no text or lettering, no watermark, no UI chrome, no 3D
> glossy render, no harsh gradients, no neon, no sparkles, no corporate-memphis
> blob-people, no generic clip-art, no photorealism, not childish or cutesy.

---

## Illustration prompts (append after the STYLE BLOCK)

### 1 · Welcome hero
A cosy, tidy study scene at a calm angle: an open notebook with a soft pencil, a
couple of neat sheets of notes, a warm mug, and two or three small science/maths
motifs gently floating above (a simple molecule, a tiny line graph, a √ symbol).
The feeling of a capable, friendly companion ready to help you study. Soft
lavender background wash.

### 2 · How I teach (the "aha")
A single rounded answer/speech bubble in soft lavender holding a small clean
explanatory diagram or a few tidy abstract lines, with a small sage-green check
and a little bookmark/tag motif beside it (suggesting a cited source). The idea
of a clear, trustworthy answer clicking into place. Minimal and focused.

### 3 · How it works / trust
A friendly smartphone shown front-on with a small lock badge on it, and behind
it a neat little stack of real lecture-note papers and a syllabus document gently
feeding into it with soft arrows. Conveys two things at once: grounded in real
study material, and your data is handled privately and securely. Calm and
reassuring. (Copy must NOT claim "on your device only" — see Honesty note below.)

### 4 · Empty state (no conversations yet)
A calm, inviting empty scene: one open notebook, a soft pencil, and a single
small drifting question-mark motif, surrounded by lots of negative space.
Friendly and welcoming, not sad or lonely.

### 5 · "Take a break" (rate-limit / capacity state)
A gentle scene: a closed notebook with a small mug and a tiny crescent-moon or
plant motif resting on top, suggesting a calm pause. Warm and kind, never an
error feeling.

---

## App icon / logo mark (different spec — keep it simple & iconic)

**Primary concept (committed):** a speech bubble + small check = "a trustworthy
answer." One concept per generation — don't list options in a single prompt.

> Square 1024×1024 app icon. Rounded-squircle tile in soft lavender-purple
> (#6B5DE0). Centered flat symbol: a bold, simple speech bubble with a small
> sage-green check inside, suggesting a trustworthy answer. Minimal, iconic,
> readable at 48px. One or two purple tones plus a small sage accent. Generous
> padding, clean rounded geometry. No text, no robot, no graduation cap, no
> sparkles, no heavy gradients, no drop shadow.

Optional comparison runs (separate generations, one concept each): a clean
monogram "J" with a subtle page fold; or an open book whose pages form a soft
upward curve.

---

## Sizes & export
| Asset | Size | Format | Background |
|---|---|---|---|
| Onboarding heroes (1–3) | 1080 × 1350 (4:5) | PNG | cream #FAF8FF *or* transparent |
| Empty / break states (4–5) | 1024 × 1024 | PNG | transparent preferred |
| App icon | 1024 × 1024 | PNG | filled squircle (no transparency) |

For light **and** dark mode: easiest is transparent-background art that sits on
either theme; if a hero has a baked cream background, also export a dark variant
(swap cream → slate #121017, keep the subject). I'll wire both into Flutter.

## Honesty note (applies to copy, not the art)
Do **not** claim "stays on your device / never uploaded." Real data flow:
`memory.md` lives on-device but its contents are sent to the backend + AI model
each turn to personalize answers, and signed-in users' conversations are stored
server-side for history. Honest copy: **"private and secure," "used only to tutor
you, never sold."** This also matters for App Store / Play privacy review. (Fix
the earlier mockup lines "Stored on your device — never uploaded" and "your notes
stay on your device" → "private & secure" when building the screens.)

## Model-specific tips
- **Midjourney:** append `--ar 4:5 --style raw --stylize 150`; reuse one `--sref`
  (style reference) across all five so the set matches. App icon: `--ar 1:1`.
- **Ideogram:** great for flat illustration + consistent style; set "no text".
- **DALL·E 3 / ChatGPT:** paste the STYLE BLOCK each time; explicitly say "flat
  vector illustration, no text, no UI." Ask for variations, keep the cohesive set.
- **Transparent PNGs:** if the model can't, export on cream and remove the bg
  after (e.g. remove.bg) — or just keep cream, it's on-palette.

## Where the files go (I'll wire these in)
```
app/assets/illustrations/onboarding_welcome.png
app/assets/illustrations/onboarding_teach.png
app/assets/illustrations/onboarding_trust.png
app/assets/illustrations/empty_chats.png
app/assets/illustrations/state_break.png
app/assets/icon/app_icon.png      (1024² → flutter_launcher_icons generates the rest)
```
Dark variants (if baked-bg heroes): same name + `_dark.png`.

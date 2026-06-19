# Google Stitch — Lactic design brief

How to use: Stitch works best as a **standing app description + per-screen
prompts**. Paste **Part A (Master brief)** as the app description / first prompt,
then generate each screen with its **Part B** prompt. Keep Part A's style summary
at the top of each screen prompt if Stitch loses the theme.

---

## PART A — MASTER BRIEF (paste first)

Design a polished **mobile app** called **Lactic**, an AI study tutor for Singapore
Junior College students preparing for the GCE A-Level (ages 16–18). It answers
their subject questions, grounded in real Singapore prelim papers and the SEAB
syllabus, and shows worked exam answers. Tone: **warm, friendly, and
encouraging, but a credible serious tool that helps them score — never childish
or toy-like.** Portrait phone screens; design for iOS and Android; support light
and dark mode.

**Design language — "Friendly Focus":** rounded, soft, approachable, with
generous whitespace and a calm premium feel. Flat UI with gentle depth (soft
shadows, hairline borders). NOT flashy, NOT corporate, NO sparkle/AI motifs.

**Color — Light mode**
- Background #FAF8FF (faint lavender paper) · Surface #FFFFFF · Recessed/muted #F1EEFA
- Text #221F33 · Muted text #6F6A82 · Hairline border #E9E4F6
- Primary (buttons, accents) #6B5DE0 · Primary text/links #5B4FCF
- Soft tint (chips, user bubbles) #EEEBFC with text #4A3D9E
- Correct/success #15803D · Caution #B45309 · Error #DC2626

**Color — Dark mode**
- Background #121017 · Surface #1A1823 · Recessed #221F2E
- Text #ECEAF2 · Muted #9D98AC · Border #2C2A38
- Primary #A99BF5 · Soft tint #2A2440 with text #C9BEFA

**Typography**
- Headings / titles: **Baloo 2** (rounded, friendly), weight 600–700
- Body / UI: **Nunito**, weight 400–600
- Working / formulas: **IBM Plex Mono**

**Shape & spacing**
- Corner radius: cards 16, buttons 12–14, input fields 14, chips/pills fully
  rounded, chat bubbles 18 (one corner squared toward the speaker), sheets 24 top
- 4/8 spacing rhythm; 20px screen side padding; touch targets ≥ 44px
- Buttons: solid primary (filled #6B5DE0, white text), secondary (surface +
  hairline border), text/ghost. Press feedback, clear disabled state.
- Icons: one rounded line-icon set (Phosphor style), consistent stroke. No emoji.

**Imagery:** onboarding is **illustration-led** — each onboarding screen has one
large warm illustration (use a placeholder image area; final art is generated
separately, flat rounded vector in the lavender palette). Elsewhere, minimal
illustration; use the semantic colors with an icon (never color alone).

**Navigation:** bottom tab bar with 4 items — Home, Chat, History, Profile (icon
+ label, active item highlighted in primary). On tablet, use a side rail + a
two-pane chat (list ‖ conversation).

---

## PART B — SCREENS (generate each)

### Onboarding (illustration-led, 4 screens, with progress dots)
1. **Welcome** — full-bleed warm illustration placeholder up top; below it a Baloo
   2 headline "Your A-Level tutor", a one-line subtitle "Grounded in real
   Singapore prelims and the SEAB syllabus — not generic AI", a primary "Get
   started" button, a small "Already have an account? Sign in" link, and a tiny
   footer "Free · private & secure".
2. **Subjects & level** — title "What are you studying?"; a level segmented
   control (H1 / H2 / H3); a 2-column grid of subject chips (Mathematics,
   Physics, Chemistry, Biology, Economics, Geography, History, General Paper, …)
   that toggle selected (soft lavender fill + check); helper line "Saved on your
   device"; primary "Continue".
3. **Live taste** — title "See how I teach"; subtitle "Tap a question — I'll
   answer it for real"; three tappable suggested-question rows; below, a sample
   answer card (a concept heading + 2 short paragraphs + two small citation
   chips); a reassurance line with a shield icon "Every answer cites real notes —
   and tells you when it's unsure"; primary "Continue".
4. **How it works / trust** — illustration placeholder; four short points each
   with an icon: "Grounded in real material", "Honest, not a know-it-all",
   "Private and secure — used only to tutor you, never sold", "Free to use";
   primary "Get started".

### Auth (optional, reachable from Welcome/Profile — not forced)
5. **Sign in** — logo, "Save your progress across devices", buttons: Continue
   with Google, **Continue with Apple**, Continue with email. Small print: terms
   + privacy. (Account is optional; the app is usable without it.)

### Core
6. **Home / Today** — greeting "Good evening, Wei" + a line like "3 days to your
   H2 Chem prelim"; a prominent "Ask anything" entry card (primary); a "Pick up
   where you left off" list of recent topics (icon + title + subject); a soft
   suggestion card driven by memory ("You've slipped on v–t graphs — want to
   drill them?"); bottom tab bar.
7. **Chat — teaching mode** — top bar: back, subject title (e.g. "H2 Chemistry")
   + a neutral "Teaching" badge, overflow. A user message bubble (right, soft
   lavender). A tutor answer (left, surface card) with a Baloo 2 concept heading,
   body text, an inline highlighted key phrase, and small citation chips ("#2
   syllabus", "#5 lecture notes"); a tiny "Grounded in 2 sources" line with a
   green check. Bottom input bar: a "Guide me / Just answer" segmented toggle, a
   text field "Ask anything…", a camera (photo a question) icon, and a primary
   send button.
8. **Chat — exam-answer mode** (a variant state) — same screen but the badge says
   "Exam answer" (primary tint); the answer leads with a named principle, shows
   step-by-step working in monospace, a bold final answer, and a small mark-
   allocation note "[3]: resolve (1), equation (1), answer with unit (1)".
9. **Chat — streaming / typing state** — show the tutor answer mid-stream with a
   subtle typing indicator.
10. **Chat — web-search consent** — an inline prompt bubble: "I can't find this in
    your A-Level materials — want me to search the web?" with "Yes, search" /
    "No thanks" buttons.
11. **History** — searchable list of past conversations grouped by date (title +
    subject + timestamp).
12. **Profile / Memory** — avatar + name + level/subjects; an editable "Struggling
    topics" list (topic, short reason, date); "Recently mastered" chips; "How I
    explain things" preference chips; a small "Your data is private and secure"
    line. An "Edit" affordance.
13. **Settings** — appearance (System / Light / Dark), default answer style (Guide
    me / Just answer), account (sign in/out, **delete account**), usage this
    month, about/privacy.

### States
14. **Empty (no conversations)** — friendly illustration placeholder + "No
    questions yet — ask me anything" + a primary CTA.
15. **Daily limit (429)** — calm illustration placeholder + "You've reached
    today's questions — back in a few hours" + secondary CTA.
16. **At capacity (503)** — "Lactic's taking a short break — try again soon."
17. **Offline / error** — clear cause + a retry button.

---

## ASSETS NEEDED (generated separately; use placeholders in Stitch)
| Asset | Where | Spec |
|---|---|---|
| Welcome illustration | Onboarding 1 | flat rounded vector, lavender palette, portrait |
| Trust illustration | Onboarding 4 | same style |
| Empty-state illustration | Empty screen | same style, square |
| "Take a break" illustration | 429 / 503 | same style, square |
| App icon | launcher | speech bubble + sage check, lavender squircle, 1024² |
| Subject glyphs | subject chips | one rounded line-icon set (Phosphor) |

## AVOID (tell Stitch)
No sparkle/✨ motifs, no generic AI look, no neon, no heavy gradients, no
childish/cartoonish styling, no emoji as icons, no color-only status, no cramped
spacing. Keep it calm, rounded, and premium.

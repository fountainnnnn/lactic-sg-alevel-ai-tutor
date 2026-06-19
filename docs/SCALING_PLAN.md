# Lactic — Scaling, Monetization & Cost Strategy

Status: strategy locked 2026-06-16. Free tier + Phase A cost controls are built;
paid tier is designed, not yet implemented (comes after the app).

## Goal & principles

This is primarily a **portfolio project**: the priority is **many real users**
on a free, genuinely useful product, with a credible paid tier as upside. Profit
is secondary; the owner is comfortable funding ~$50/mo of running cost.

1. **Free studying is never interrupted or rationed.** Caps exist only to stop
   abuse, set far above honest use.
2. **Cost is bounded, never a surprise** — a global circuit-breaker caps the
   monthly bill; past it the app degrades, it doesn't die or overspend.
3. **Quality is matched to stakes** — cheapest model for the easy majority, the
   stronger model only where it matters (mostly the paid tier).
4. **Paid is a different job** (a proactive exam-prep machine), not a
   less-crippled free.

## Tiers

### Free (everyone) — a reactive tutor
- The full tutor: concept explanations, follow-ups, exam-answer technique,
  citations, memory — effectively unlimited for normal use.
- Runs on the cheap model tier (Gemini Flash-Lite), benchmarked as sufficient
  for this (see Model tiering).
- This is the whole, real product. It is what wins users.

### Premium (paid) — a proactive exam-prep machine
The reason to pay is **not** a single convenience feature (OCR alone does not
convert). It is a set of grade-improving capabilities free users don't get:

1. **Answer Feedback (flagship).** Formative, mark-scheme-grounded review of the
   student's own work: where marks are won/lost, examiner keyword phrasing.
   **Never an authoritative grade** — banded and "indicative", teacher is the
   final authority. Named "Answer Feedback" / "Marks Coach", never "AI examiner".
   Grounded in the real mark-scheme corpus; scoped to where it's reliable.
2. **Weak-spot drilling.** Targeted real-prelim question sets from the student's
   struggling-topic memory + similar-question edges.
3. **Progress / mastery view.** Improvement over time, readiness by topic.
4. **Bundled perks (not the headline):** photo/OCR question upload, automatic
   escalation to the stronger model on hard problems, no budget-degradation.

### Conversion — without interrupting study
- Contextual, ignorable offers at the moment of relevance ("Want me to review
  this against the mark scheme? (Premium)").
- One free taste of Answer Feedback, ever.
- Exam-season foregrounding (willingness-to-pay spikes near prelims/A-Levels).
- Never a wall in the study flow.

## Model tiering (benchmarked 2026-06-16)

Verdict from `evals/model_bench.py` (behavioural) + `evals/judge_bench.py`
(LLM-judge quality, blind dual-order, objective answer-keys):

| Tier | Used for | Model |
|---|---|---|
| Aux | classify / rerank / memory | Flash-Lite |
| Free core | explanations, follow-ups | Flash-Lite |
| Deep | hard derivations, conceptual, exam | Flash |
| Premium / escalate | marking, "I'm stuck" | Flash / Pro |
| Overflow | budget-degraded fallback | free model |

- Behavioural suite tied across all tiers (41/41).
- Hard judge eval: Flash beats Lite on **conceptual-trap reasoning** (objective
  answer-keys ~tied; judge favours Flash on subtle explanation). So Lite is
  correct + good enough for the free core; the harder slice uses Flash.
- Free models cannot be the primary tier (OpenRouter free routing ~1000 req/day
  shared across the whole key) — they are the budget-degradation fallback only.

## Cost controls (built — Phase A)

1. **Answer cache** — repeat questions are free; hit-rate climbs as cohorts
   converge on the same prelim questions. Caches only stable concept/find
   answers (never exam-mode numeric solves or degraded answers).
2. **Difficulty routing** — most turns on the cheapest model.
3. **Per-turn cost telemetry** (`usage_log`) — exact cost/latency per turn.
4. **Per-user rate limits** — abuse caps (`TURNS_PER_MINUTE`, `TURNS_PER_DAY`).
5. **Global budget circuit-breaker** — `usage_limits` RPC sums month-to-date
   spend; over `MONTHLY_BUDGET_USD` the app degrades generation to the free
   `MODEL_OVERFLOW` model (stays up) or returns 503 if none configured.

Indicative cost: ~$0.001 cold turn, $0 cached, plus a fixed ~$25/mo Supabase
floor. Portfolio-scale traffic stays well under the budget; the breaker caps the
tail regardless.

## Build order

- **Phase A — wallet safety (done):** budget breaker, telemetry, rate limits,
  answer cache, model tiering.
- **Phase B — the app:** Flutter free tier, low-friction auth, uninterrupted
  chat. (Flip `ALLOW_ANON` to 0 when auth ships.)
- **Phase C — paid flagship:** Answer Feedback (formative/grounded/banded) +
  entitlement check + calibration measurement (agreement vs official marks).
- **Phase D — prep machine:** weak-spot drilling, progress view, semantic cache.

## Ads — decision

No ads in the study flow. Given the portfolio goal and how low/bounded the cost
is, ads are not worth the UX cost. If ever revisited: opt-in rewarded video only
at a limit-wall, never interrupting study, and contextual (minor-safe). Direct
sponsorships (tuition centres, assessment-book publishers) would beat ad-network
inventory in this niche if monetization is ever pursued.

## Portfolio framing

Track (telemetry supports it): active users, turns, cache hit-rate, cost/user,
cost/day, conversion %. Narrative: a free A-Level tutor scaled to N students on a
fixed budget via tiered model routing, a warming answer cache, and a budget
circuit-breaker — with a freemium exam-prep machine (mark-scheme-grounded
feedback, weak-spot drilling) — taking the initiative to help students while
building a real business.

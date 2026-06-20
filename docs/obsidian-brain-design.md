# Obsidian Brain — Design (knowledge graph over analyzed_notes)

Status: **DESIGN ONLY** (not built). Author pass: 2026-06-21.

## 1. What this is (and isn't)

An "obsidian brain" = a web of interlinked notes you can both **search** (by meaning)
and **traverse** (by explicit links), like Obsidian's `[[wiki-links]]` + graph view.

Honest positioning — this is an **augmentation of**, not a replacement for, the
existing HNSW vector search:

- HNSW (vector) stays the workhorse: it finds the *entry* notes for a student's
  question. Nothing replaces it; a graph is not "faster than HNSW."
- The graph adds the **structure vector search cannot express**: which notes are
  the *same topic*, and which concepts are *prerequisites* of others.
- For pure concept lookups ("explain photosynthesis"), vector already wins (a math
  textbook study found vector RAG beat GraphRAG). The graph's payoff is
  **prerequisite scaffolding, topic navigation, and learning paths** — tutoring
  value HNSW can't give.

Deliberately **excluded: similarity edges.** "Nearest by embedding" is exactly what
HNSW already does — similarity edges would duplicate it. The graph only stores what
HNSW can't: `same_topic` and `prereq`.

## 2. Schema reality (drives the design)

From the live DB (`analyzed_notes`, 99,965 rows):

| Field | State | Use |
|---|---|---|
| `topics` (text[]) | populated 99,961/99,965 | **primary** same-topic key |
| `subject` (text) | 34 distinct | scope edges within a subject |
| `syllabus_refs` (text[]) | populated | secondary same-topic key |
| `syllabus_code` (text) | **all NULL** | unusable — do not rely on it |
| `difficulty` (smallint) | populated | prereq ordering (easier → harder) |
| `embedding_content` (vector 1024) | populated | tie-breaking / fan-out capping |
| (no `prereq_*` field) | — | prereqs come from `documents`, see below |

Crucial find: **`documents.prereq_topics` has data on 387/388 rows** — the SEAB
syllabus sections carry topic→prerequisite mappings. So prerequisite edges can be
**syllabus-grounded** (authoritative, ~free) rather than LLM-guessed.

## 3. Data model

New table `note_edges` (notes ↔ notes; the existing `edges` table references
`documents`, a different entity — keep them separate):

```sql
create table public.note_edges (
  src  text not null references public.analyzed_notes(id) on delete cascade,
  dst  text not null references public.analyzed_notes(id) on delete cascade,
  rel  text not null check (rel in ('same_topic','prereq')),
  w    real not null default 1.0,           -- weight / confidence
  primary key (src, dst, rel)
);
create index note_edges_src on public.note_edges (src, rel);
create index note_edges_dst on public.note_edges (dst, rel);  -- reverse / "what depends on me"
alter table public.note_edges enable row level security;       -- no client policy: service-role only
```
`prereq` is **directional** (src is a prerequisite of dst). `same_topic` is stored
both ways (or treated as undirected at query time).

## 4. Edge construction

### 4a. same_topic edges — cheap, deterministic, no LLM
Link notes that share `topics` within the same `subject` (with `syllabus_refs` as a
secondary signal). To avoid edge explosion (a topic with 5,000 notes → 25M edges),
**cap fan-out**: each note links to its top-N (default 12) same-topic notes, ranked
by topic-overlap count, then by embedding proximity as a tie-break (using HNSW).

```
for each note A:
  candidates = notes B (B.subject = A.subject AND A.topics ∩ B.topics ≠ ∅, B ≠ A)
  rank by |A.topics ∩ B.topics| desc, then embedding distance asc
  edge(A, B, 'same_topic', w = overlap_score) for top-12
```
Built in `ingest/` (Python + SQL); ~free, minutes to run.

### 4b. prereq edges — syllabus-grounded first, LLM only for gaps
1. Build a **topic→prereq-topic** map from `documents.prereq_topics` (387 syllabus
   sections). This is the authoritative SEAB structure.
2. Project to notes: for prereq pair (topic P → topic Q), add `prereq` edges from
   notes tagged P to notes tagged Q (same subject), capped per note. `difficulty`
   refines direction (a lower-difficulty P-note is the stronger prerequisite).
3. **LLM fallback (optional, bounded):** for concept notes whose topics have no
   syllabus prereq mapping, one cheap LLM pass per note ("name the 1-3 concepts a
   student must understand first") → match returned names to existing notes by
   title/topic. Scope: only `kind='concept'` notes (14,613), only the gaps. Cost
   ~$0.0005/note → a few dollars worst case; near-zero if syllabus map covers most.

Why syllabus-first: prerequisites are pedagogical truth, and the SEAB syllabus
already encodes them. LLM-guessed prereqs are noisy; use them only to fill holes.

## 5. Retrieval integration (Phase 2 — only after validation)

GraphRAG pattern, layered onto current retrieval:
1. HNSW finds entry notes (unchanged).
2. Expand: pull `same_topic` neighbors (breadth) and `prereq` ancestors (depth) of
   the entry notes, 1 hop, capped.
3. Rerank the union; build context as today.

Plus direct **tutoring features** the graph unlocks (higher value than the retrieval
tweak):
- **Prerequisite scaffolding:** when a student struggles with Q, surface its
  `prereq` ancestors ("make sure you're solid on X and Y first").
- **Learning paths / weak-spot drilling order:** walk `prereq` edges to sequence
  practice from foundations up (ties into the existing Max "weak-spot drilling").
- **"Related topics":** `same_topic` neighbors as see-also suggestions.

## 6. Moving forward (incremental, "it should do it")

A `ingest/build_note_edges.py` (adapting the existing `build_similar_edges.py`):
- `--full` rebuild, or default **incremental** (only notes with no edges yet).
- Hook into `ingest/upload_analyzed.py` so every new note batch gets its
  same_topic edges immediately (cheap) and prereq edges from the syllabus map.
- Re-run the LLM gap-fill only for new concept notes lacking syllabus prereqs.

## 7. Phased plan

- **Phase 0 (this doc).**
- **Phase 1 — build the brain (no live-retrieval change):** create `note_edges`;
  `build_note_edges.py` (same_topic + syllabus-grounded prereq); ingest hook;
  validate edge quality on a sample (spot-check 20 prereq chains per subject).
- **Phase 2 — use it:** wire graph-expansion into `retrieve_analyzed_notes` +
  agent.ts; ship the prerequisite-scaffolding tutoring feature; A/B vs current
  retrieval before committing the retrieval change.

## 8. Effort & cost

| Piece | Effort | Cost |
|---|---|---|
| `note_edges` schema | trivial | — |
| same_topic builder | small (SQL/Python, capped fan-out) | ~free |
| prereq from syllabus map | medium (topic-map projection) | ~free |
| prereq LLM gap-fill | medium | ~few $ one-time, only for gaps |
| ingest hook (incremental) | small | per-note pennies |
| Phase 2 retrieval + tutoring | medium | dev only |

## 9. Risks / honest notes

- **Edge explosion** if fan-out isn't capped — cap at top-N per note per rel.
- **Prereq noise** from the LLM fallback — keep it minimal; trust the syllabus map.
- **Accuracy gain for plain lookups is modest** — the real value is prereq
  scaffolding + navigation, so Phase 2 should validate before changing live
  retrieval (a math-heavy app where vector already does well).
- **34 "subjects"** is more than the ~10 A-Level subjects — likely sub-variants;
  confirm the grouping key so same_topic edges don't fragment or over-merge.
- The corpus is now locked down (service-role only) — `note_edges` follows the same
  posture (RLS on, no client policy; built + read by the service role).

## 10. Open decisions (before Phase 1)

1. same_topic fan-out N (default 12) and whether to require subject match (yes).
2. Whether to run the prereq LLM gap-fill at all in v1, or ship syllabus-only first.
3. Confirm the `subject` grouping key (resolve the 34-vs-10 subjects question).

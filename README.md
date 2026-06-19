# Lactic — A-Level Study Agent (Backend)

RAG study **agent** for Singapore JC students. Graph-structured retrieval vault +
deterministic agent harness + per-user on-device memory. Single-vendor LLM stack
(Gemini 2.5 Flash) + Voyage embeddings. See the approved plan for full design.

## Status

| Layer | State |
|---|---|
| Corpus (`corpus/`) | ✅ 597 PDFs / 2.1 GB downloaded |
| Vault (`vault/notes/`) | ✅ 2,882 atomic notes built |
| Chunks (`vault/index/chunks.jsonl`) | ✅ 31,618 chunks (p95 601 tok) |
| Graph (`vault/graph/edges.jsonl`) | ⏳ scaffold built; rich edges need enrichment |
| SQL migrations (`supabase/migrations/`) | ✅ written |
| Edge Functions (`supabase/functions/`) | ✅ written (chat/ocr/search) |
| System prompts (`prompts/`) | ⏳ generating; fallbacks live in `_shared/prompts.ts` |
| Enrichment / embeddings / upload | ⛔ needs API keys (below) |

## Required credentials (`.env`)

Copy `.env.example` → `.env` and fill:

```
SUPABASE_URL=                  # from Supabase dashboard → Project Settings → API
SUPABASE_SERVICE_ROLE_KEY=     # same page (server-side only)
SUPABASE_ANON_KEY=             # same page (client)
OPENROUTER_API_KEY=            # https://openrouter.ai/keys — fronts all generation models
VOYAGE_API_KEY=                # https://dashboard.voyageai.com — embeddings only
```

Generation runs through **OpenRouter** (one key, automatic provider failover, no
single-vendor rate ceiling). Model slugs are env-configurable — see `.env.example`.
Default stack: DeepSeek V4 Flash (fast), DeepSeek R1 (deep), Kimi K2 (escalation),
Qwen2.5-VL (OCR). Embeddings stay on Voyage (1 call/turn, limits are a non-issue).

## Runbook (order matters)

```bash
# 0. deps
pip install -r ingest/requirements.txt

# 1. build vault from corpus  (done — 2,882 notes)
python -m ingest.build_vault

# 2. chunk  (done — 31,618 chunks)
python -m ingest.chunker

# 3. enrich notes (topics, HyDE, difficulty)   [needs GEMINI_API_KEY]
python -m ingest.enricher --limit 20    # test slice first
python -m ingest.enricher               # full (~2,800 notes, ~$0.40)

# 4. build the knowledge graph (rich edges now that topics exist)
python -m ingest.build_graph

# 5. apply DB schema
supabase link --project-ref <ref>
supabase db push

# 6. embed + upload   [needs VOYAGE + SUPABASE keys]
python -m ingest.embed_and_upload --limit 50   # test slice
python -m ingest.embed_and_upload              # full (~95k embeds, ~$2-3)

# 7. deploy edge functions
supabase functions deploy chat ocr search

# 8. set function secrets
supabase secrets set OPENROUTER_API_KEY=... VOYAGE_API_KEY=...

# 9. smoke test retrieval
curl -X POST "$SUPABASE_URL/functions/v1/search" \
  -H "content-type: application/json" \
  -d '{"query":"equation of motion under constant acceleration","subject":"H2_Physics"}'
```

## Architecture (one screen)

```
corpus/*.pdf
   │  ingest/parsers (PyMuPDF)         Stage A
   ▼
vault/notes/*.md  (2,882 atomic notes, YAML frontmatter)
   │  ingest/enricher (Gemini Flash)   Stage B   ← topics, HyDE, difficulty
   │  ingest/build_graph                Stage C   ← typed edges
   │  ingest/chunker (tiktoken)         Stage D   ← 31,618 chunks
   │  ingest/embed_and_upload (Voyage)  Stage E   ← 3-view embeddings
   ▼
Supabase Postgres (documents, chunks[3×vector], edges) + RLS
   │  retrieve_context RPC (vector ∪ hyde ∪ bm25)
   ▼
Edge Function `chat` — agent harness (_shared/agent.ts):
   parse_memory → classify → clarify? → reformulate → retrieve →
   rerank (Gemini in-context) → graph_expand → plan_pedagogy →
   generate (Flash/Pro, streamed SSE) → memory_delta
   ▼
React Native + Expo app (separate workstream) — renders markdown+LaTeX,
   owns memory.md, handles SSE, image upload for OCR.
```

## Layout

```
ingest/          Python ingestion pipeline
  common.py      Note dataclass, PDF cleanup, vault IO
  parsers/       syllabus.py, textbook.py, papers.py
  build_vault.py · chunker.py · enricher.py · build_graph.py · embed_and_upload.py
  llm.py         Gemini + Voyage clients (Python)
supabase/
  migrations/    0001-0004 schema + RPCs
  functions/     chat/ ocr/ search/ + _shared/
prompts/         01-08 system prompts (pedagogical IP)
vault/           generated retrieval substrate (gitignored)
```

## Cost (heavy user, ~1500 turns/mo): ~$1.50. See plan §Stack.

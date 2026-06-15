-- Global answer cache. Students share the same prelim papers and ask the same
-- questions; a standalone, non-personalised content question can be served from
-- here, skipping retrieval + rerank + generate + memory-writer entirely.
-- Keyed by a hash of (prompt-version, normalised question, subject/level hints,
-- answer style, exam-vs-teach mode) — computed in the agent.

create table if not exists answer_cache (
  key text primary key,
  question text,                 -- original text, for inspection/debugging
  answer text not null,
  citations jsonb,
  model text,
  hits int not null default 0,
  created_at timestamptz not null default now(),
  last_hit_at timestamptz
);

create index if not exists answer_cache_created on answer_cache (created_at);

alter table answer_cache enable row level security;
-- no policies: only the service role (Edge Function) touches this table

-- atomic hit-counter bump (fire-and-forget from the agent on a cache hit)
create or replace function bump_answer_cache(p_key text)
returns void language sql security definer set search_path = public as $$
  update answer_cache set hits = hits + 1, last_hit_at = now() where key = p_key;
$$;

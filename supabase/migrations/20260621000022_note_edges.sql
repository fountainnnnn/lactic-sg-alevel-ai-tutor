-- Obsidian-brain knowledge graph over analyzed_notes (Phase 1: data layer only;
-- live retrieval is unchanged until Phase 2). Stores ONLY the structure HNSW
-- can't express: same_topic (lateral navigation) and prereq (directional
-- "learn src before dst"). Similarity edges are intentionally omitted — that's
-- exactly what the vector index already does.
--
-- Built + read by the service role only (same lockdown posture as the corpus).

create table if not exists public.note_edges (
  src text not null references public.analyzed_notes(id) on delete cascade,
  dst text not null references public.analyzed_notes(id) on delete cascade,
  rel text not null check (rel in ('same_topic','prereq')),
  w   real not null default 1.0,
  primary key (src, dst, rel)
);

create index if not exists note_edges_src on public.note_edges (src, rel);
create index if not exists note_edges_dst on public.note_edges (dst, rel);

alter table public.note_edges enable row level security; -- no client policy: service-role only
revoke all on public.note_edges from anon, authenticated;

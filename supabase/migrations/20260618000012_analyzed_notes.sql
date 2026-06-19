-- ============================================================
-- Analyzed notes: store ORIGINAL, derived knowledge instead of third-party
-- copyrighted text (prelims, TYS, school lecture notes).
--
-- An analyzed note captures the unprotectable facts + our own analysis: topic,
-- what is taught, how it is taught, the skill tested, HOW it is tested, the
-- question pattern, the expected answer structure, common mistakes, and an
-- original explanation. No identifying provenance (school / year / paper /
-- "is-TYS") is stored in this public-read table.
--
-- Non-destructive: existing documents/chunks (Tier-1 open content: OpenStax,
-- syllabus, specimen) are left intact. Tier-2 raw text is purged from documents
-- only at cutover, in a later migration, once analyzed notes are populated.
-- ============================================================

create table if not exists analyzed_notes (
  id text primary key,
  kind text not null check (kind in ('concept','question_pattern')),
  -- facts needed for retrieval filtering (not copyrightable)
  subject text,
  syllabus_code text,
  syllabus_refs text[] not null default '{}',
  topics text[] not null default '{}',
  title text not null,
  difficulty smallint check (difficulty between 1 and 5),
  -- derived knowledge — all original prose, never a verbatim source excerpt
  topic_summary    text,
  what_taught      text,
  how_taught       text,
  skill_tested     text,
  how_tested       text,          -- how this shows up in exams: forms, command words, marks
  pattern          text,          -- recurring question archetype (question_pattern notes)
  answer_structure text,          -- expected answer skeleton / mark logic (original)
  common_mistakes  text[] not null default '{}',
  explanation      text,          -- canonical worked method / model explanation
  keywords         text[] not null default '{}',
  -- retrieval
  embedding_content vector(1024),
  embedding_hyde    vector(1024),
  tsv tsvector generated always as (
    to_tsvector('english',
      coalesce(title,'') || ' ' || coalesce(topic_summary,'') || ' ' ||
      coalesce(what_taught,'') || ' ' || coalesce(how_taught,'') || ' ' ||
      coalesce(skill_tested,'') || ' ' || coalesce(how_tested,'') || ' ' ||
      coalesce(pattern,'') || ' ' || coalesce(answer_structure,'') || ' ' ||
      coalesce(explanation,'')
    )
  ) stored,
  updated_at timestamptz not null default now()
);

create index analyzed_notes_subject  on analyzed_notes(subject);
create index analyzed_notes_kind     on analyzed_notes(kind);
create index analyzed_notes_topics   on analyzed_notes using gin(topics);
create index analyzed_notes_syllabus on analyzed_notes using gin(syllabus_refs);
create index analyzed_notes_kw       on analyzed_notes using gin(keywords);
create index analyzed_notes_tsv      on analyzed_notes using gin(tsv);
create index analyzed_notes_ec       on analyzed_notes using hnsw (embedding_content vector_cosine_ops);
create index analyzed_notes_eh       on analyzed_notes using hnsw (embedding_hyde    vector_cosine_ops);

alter table analyzed_notes enable row level security;
-- public read; writes only via service role (bypasses RLS)
create policy analyzed_notes_read on analyzed_notes for select using (true);

-- ============================================================
-- analyzed_note_sources: PRIVATE dedup/audit map. Service-role only (no select
-- policy), so it is never exposed to the app or the public. Stores only a content
-- hash and a coarse tier — NEVER the source text or identifying school/year/paper.
-- ============================================================
create table if not exists analyzed_note_sources (
  note_id      text not null references analyzed_notes(id) on delete cascade,
  source_sha256 text not null,
  source_tier  text not null check (source_tier in ('prelim','tys','school_notes','open')),
  derived_at   timestamptz not null default now(),
  primary key (note_id, source_sha256)
);
create index analyzed_note_sources_hash on analyzed_note_sources(source_sha256);
alter table analyzed_note_sources enable row level security;  -- no policies => service-role only

-- ============================================================
-- retrieve_analyzed_notes: hybrid retrieval over analyzed notes
--   vector(content) ∪ vector(hyde) ∪ BM25, RRF-fused (mirrors retrieve_context).
-- Returns a composed body of the derived knowledge for the agent to read.
-- ============================================================
create or replace function retrieve_analyzed_notes(
  q_embed    vector(1024),
  q_text     text,
  hyde_embed vector(1024) default null,
  f_subjects text[] default null,
  f_kind     text default null,
  k          int default 40
) returns table (
  note_id text, title text, content text, kind text, score real, hit_source text
) language plpgsql stable as $$
#variable_conflict use_column
declare
  pool int := greatest(k * 3, 120);
  tsq  tsquery := plainto_tsquery('english', q_text);
begin
  perform set_config('hnsw.ef_search', '200', true);
  perform set_config('ivfflat.probes', '10', true);  -- ivfflat indexes: lift recall

  return query
  with base as (
    select a.* from analyzed_notes a
    where (f_subjects is null or a.subject = any(f_subjects))
      and (f_kind     is null or a.kind = f_kind)
  ),
  note_text as (
    select b.id, b.title, b.kind,
      concat_ws(E'\n',
        '# ' || b.title,
        nullif(b.what_taught, ''),
        nullif(b.how_taught, ''),
        case when b.skill_tested     is not null then 'Skill: ' || b.skill_tested end,
        case when b.how_tested       is not null then 'How it is tested: ' || b.how_tested end,
        case when b.pattern          is not null then 'Pattern: ' || b.pattern end,
        case when b.answer_structure is not null then 'Answer structure: ' || b.answer_structure end,
        case when array_length(b.common_mistakes, 1) > 0
             then 'Common mistakes: ' || array_to_string(b.common_mistakes, '; ') end,
        nullif(b.explanation, '')
      ) as body,
      b.embedding_content as ec, b.embedding_hyde as eh, b.tsv as tv
    from base b
  ),
  v_content as (
    select id, title, kind, body, 'vc' as src,
           row_number() over (order by ec <=> q_embed, id) as r
    from note_text where ec is not null order by ec <=> q_embed limit pool
  ),
  v_hyde as (
    select id, title, kind, body, 'vh' as src,
           row_number() over (order by eh <=> coalesce(hyde_embed, q_embed), id) as r
    from note_text where eh is not null order by eh <=> coalesce(hyde_embed, q_embed) limit pool
  ),
  bm25 as (
    select id, title, kind, body, 'bm' as src,
           row_number() over (order by ts_rank_cd(tv, tsq) desc, id) as r
    from note_text where tv @@ tsq order by ts_rank_cd(tv, tsq) desc limit pool
  ),
  unioned as (
    select * from v_content union all select * from v_hyde union all select * from bm25
  ),
  fused as (
    select u.id, min(u.title) as title, min(u.kind) as kind, min(u.body) as body,
           sum(1.0 / (60 + u.r))::real as s,
           string_agg(distinct u.src, ',') as srcs
    from unioned u group by u.id
  )
  select f.id, f.title, f.body, f.kind, f.s, f.srcs
  from fused f order by f.s desc limit k;
end;
$$;

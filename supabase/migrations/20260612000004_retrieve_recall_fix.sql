-- ============================================================
-- Fix the post-filter recall cliff + SQL cleanups.
--
-- Problem: HNSW default ef_search=40 returns ~40 candidates per leg BEFORE the
-- subject/year/school filter is applied. For a non-dominant subject (e.g.
-- H2 Further Mathematics, 222 docs) the filter cut k=60 down to 4 rows.
--
-- Fixes:
--   * set_config('hnsw.ef_search', 400, local) — widen the candidate pool so
--     selective filters still leave enough survivors. (The SET-clause form is
--     permission-denied on the managed role; set_config at runtime is allowed.)
--   * overfetch per leg (k*3) before the filter bites.
--   * GROUP BY cid only (chunk PK) — was grouping on full body text.
--   * compute plainto_tsquery once.
--   * row_number tie-breaker (c.id) for deterministic ranks.
-- ============================================================
create or replace function retrieve_context(
  q_embed vector(1024),
  q_text text,
  hyde_embed vector(1024) default null,
  f_subject text default null,
  f_year_min int default null,
  f_school text default null,
  f_type text default null,
  k int default 60
) returns table (
  chunk_id text,
  document_id text,
  content text,
  heading_path text,
  score real,
  hit_source text
) language plpgsql stable as $$
declare
  pool int := greatest(k * 3, 120);
  tsq tsquery := plainto_tsquery('english', q_text);
begin
  -- widen HNSW search so the post-filter has enough candidates to survive
  perform set_config('hnsw.ef_search', '200', true);

  return query
  with v_content as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, 'vc' as src,
           row_number() over (order by c.embedding_content <=> q_embed, c.id) as r
    from chunks c join documents d on d.id = c.document_id
    where (f_subject  is null or d.subject = f_subject)
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
    order by c.embedding_content <=> q_embed
    limit pool
  ),
  v_hyde as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, 'vh' as src,
           row_number() over (order by c.embedding_hyde <=> coalesce(hyde_embed, q_embed), c.id) as r
    from chunks c join documents d on d.id = c.document_id
    where (f_subject  is null or d.subject = f_subject)
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
    order by c.embedding_hyde <=> coalesce(hyde_embed, q_embed)
    limit pool
  ),
  bm25 as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, 'bm' as src,
           row_number() over (order by ts_rank_cd(c.tsv, tsq) desc, c.id) as r
    from chunks c join documents d on d.id = c.document_id
    where c.tsv @@ tsq
      and (f_subject  is null or d.subject = f_subject)
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
    order by ts_rank_cd(c.tsv, tsq) desc
    limit pool
  ),
  unioned as (
    select * from v_content
    union all select * from v_hyde
    union all select * from bm25
  ),
  fused as (
    select u.cid,
           min(u.did) as did, min(u.body) as body, min(u.hp) as hp,
           sum(1.0 / (60 + u.r))::real as s,
           string_agg(distinct u.src, ',') as srcs
    from unioned u
    group by u.cid
  )
  select f.cid, f.did, f.body, f.hp, f.s, f.srcs
  from fused f order by f.s desc limit k;
end;
$$;

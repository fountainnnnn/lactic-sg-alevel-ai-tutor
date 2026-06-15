-- ============================================================
-- Add f_subjects (array) to retrieve_context for H1<->H2 cross-level fallback.
-- H1 content is a subset of H2, so a student of either level should be able to
-- draw on the same-root teaching notes across levels. f_subject (singular) kept
-- for back-compat; when f_subjects is provided it takes precedence.
-- ============================================================
create or replace function retrieve_context(
  q_embed vector(1024),
  q_text text,
  hyde_embed vector(1024) default null,
  f_subject text default null,
  f_year_min int default null,
  f_school text default null,
  f_type text default null,
  k int default 60,
  f_types text[] default null,
  f_licenses text[] default null,
  f_subjects text[] default null
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
  perform set_config('hnsw.ef_search', '200', true);

  return query
  with v_content as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, 'vc' as src,
           row_number() over (order by c.embedding_content <=> q_embed, c.id) as r
    from chunks c join documents d on d.id = c.document_id
    where (f_subjects is not null and d.subject = any(f_subjects)
           or f_subjects is null and (f_subject is null or d.subject = f_subject))
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
      and (f_types    is null or d.type = any(f_types))
      and (f_licenses is null or d.license = any(f_licenses))
    order by c.embedding_content <=> q_embed
    limit pool
  ),
  v_hyde as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, 'vh' as src,
           row_number() over (order by c.embedding_hyde <=> coalesce(hyde_embed, q_embed), c.id) as r
    from chunks c join documents d on d.id = c.document_id
    where (f_subjects is not null and d.subject = any(f_subjects)
           or f_subjects is null and (f_subject is null or d.subject = f_subject))
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
      and (f_types    is null or d.type = any(f_types))
      and (f_licenses is null or d.license = any(f_licenses))
    order by c.embedding_hyde <=> coalesce(hyde_embed, q_embed)
    limit pool
  ),
  bm25 as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, 'bm' as src,
           row_number() over (order by ts_rank_cd(c.tsv, tsq) desc, c.id) as r
    from chunks c join documents d on d.id = c.document_id
    where c.tsv @@ tsq
      and (f_subjects is not null and d.subject = any(f_subjects)
           or f_subjects is null and (f_subject is null or d.subject = f_subject))
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
      and (f_types    is null or d.type = any(f_types))
      and (f_licenses is null or d.license = any(f_licenses))
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

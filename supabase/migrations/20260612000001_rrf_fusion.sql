-- ============================================================
-- RRF fusion for retrieve_context.
-- The previous version fused legs with max(score), but cosine similarity
-- (~0.6-0.9) and ts_rank_cd (~0.01-0.1) are incomparable scales — BM25 hits
-- could never win. Reciprocal Rank Fusion scores each leg by rank instead:
--   score = sum over legs of 1 / (60 + rank_in_leg)
-- A chunk found by multiple legs accumulates, which is exactly the hybrid
-- signal we want.
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
) language sql stable as $$
  with filt as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, c.embedding_content as ec,
           c.embedding_hyde as eh, c.tsv as tv
    from chunks c
    join documents d on d.id = c.document_id
    where (f_subject  is null or d.subject = f_subject)
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
  ),
  v_content as (
    select cid, did, body, hp, 'vc' as src,
           row_number() over (order by ec <=> q_embed) as r
    from filt where ec is not null
    order by ec <=> q_embed limit greatest(k/2, 20)
  ),
  v_hyde as (
    select cid, did, body, hp, 'vh' as src,
           row_number() over (order by eh <=> coalesce(hyde_embed, q_embed)) as r
    from filt where eh is not null
    order by eh <=> coalesce(hyde_embed, q_embed) limit greatest(k/2, 20)
  ),
  bm25 as (
    select cid, did, body, hp, 'bm' as src,
           row_number() over (
             order by ts_rank_cd(tv, plainto_tsquery('english', q_text)) desc) as r
    from filt
    where tv @@ plainto_tsquery('english', q_text)
    order by ts_rank_cd(tv, plainto_tsquery('english', q_text)) desc
    limit greatest(k/2, 20)
  ),
  unioned as (
    select * from v_content
    union all select * from v_hyde
    union all select * from bm25
  ),
  fused as (
    select cid, did, body, hp,
           sum(1.0 / (60 + r))::real as s,
           string_agg(distinct src, ',') as srcs
    from unioned
    group by cid, did, body, hp
  )
  select cid, did, body, hp, s, srcs
  from fused order by s desc limit k;
$$;

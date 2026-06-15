-- ============================================================
-- Make retrieve_context use the HNSW indexes.
-- The previous version pre-joined chunks+documents in a CTE, which blocked
-- index-ordered scans and seq-scanned 149k vectors (~25s, statement timeout).
-- Each leg now orders `chunks` directly — the planner does an HNSW index scan,
-- nested-loop joins documents by pk, filters, and stops at the limit.
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
  with v_content as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, 'vc' as src,
           row_number() over (order by c.embedding_content <=> q_embed) as r
    from chunks c join documents d on d.id = c.document_id
    where (f_subject  is null or d.subject = f_subject)
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
    order by c.embedding_content <=> q_embed
    limit greatest(k/2, 20)
  ),
  v_hyde as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, 'vh' as src,
           row_number() over (order by c.embedding_hyde <=> coalesce(hyde_embed, q_embed)) as r
    from chunks c join documents d on d.id = c.document_id
    where (f_subject  is null or d.subject = f_subject)
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
    order by c.embedding_hyde <=> coalesce(hyde_embed, q_embed)
    limit greatest(k/2, 20)
  ),
  bm25 as (
    select c.id as cid, c.document_id as did, c.content as body,
           c.heading_path as hp, 'bm' as src,
           row_number() over (
             order by ts_rank_cd(c.tsv, plainto_tsquery('english', q_text)) desc) as r
    from chunks c join documents d on d.id = c.document_id
    where c.tsv @@ plainto_tsquery('english', q_text)
      and (f_subject  is null or d.subject = f_subject)
      and (f_year_min is null or d.year is null or d.year >= f_year_min)
      and (f_school   is null or d.school = f_school)
      and (f_type     is null or d.type = f_type)
    order by ts_rank_cd(c.tsv, plainto_tsquery('english', q_text)) desc
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

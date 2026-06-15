-- ============================================================
-- retrieve_context as plpgsql.
-- Via PostgREST, args arrive through a lateral JSON unpack; the inlined SQL
-- function then plans without a constant query vector and seq-scans (~16s).
-- plpgsql plans its inner statement with the args as real parameters, so the
-- HNSW index scans kick in (~0.6s). ef_search=100 keeps recall up when the
-- subject filter discards index candidates.
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
begin
  return query
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
    select u.cid, u.did, u.body, u.hp,
           sum(1.0 / (60 + u.r))::real as s,
           string_agg(distinct u.src, ',') as srcs
    from unioned u
    group by u.cid, u.did, u.body, u.hp
  )
  select f.cid, f.did, f.body, f.hp, f.s, f.srcs
  from fused f order by f.s desc limit k;
end;
$$;

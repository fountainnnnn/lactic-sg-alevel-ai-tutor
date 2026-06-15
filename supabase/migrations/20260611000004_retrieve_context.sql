-- ============================================================
-- retrieve_context: single-round-trip hybrid retrieval
--   vector(content) ∪ vector(hyde) ∪ BM25, with metadata filters
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
    select cid, did, body, hp,
           (1 - (ec <=> q_embed))::real as s, 'vc' as src
    from filt where ec is not null
    order by ec <=> q_embed limit greatest(k/3, 10)
  ),
  v_hyde as (
    select cid, did, body, hp,
           (1 - (eh <=> coalesce(hyde_embed, q_embed)))::real as s, 'vh' as src
    from filt where eh is not null
    order by eh <=> coalesce(hyde_embed, q_embed) limit greatest(k/3, 10)
  ),
  bm25 as (
    select cid, did, body, hp,
           ts_rank_cd(tv, plainto_tsquery('english', q_text))::real as s, 'bm' as src
    from filt
    where tv @@ plainto_tsquery('english', q_text)
    order by s desc limit greatest(k/3, 10)
  ),
  unioned as (
    select * from v_content
    union all select * from v_hyde
    union all select * from bm25
  ),
  best as (
    select cid, did, body, hp,
           max(s) as s,
           string_agg(distinct src, ',') as srcs
    from unioned
    group by cid, did, body, hp
  )
  select cid, did, body, hp, s, srcs
  from best order by s desc limit k;
$$;

-- structured lookup: "show me 2024 RI Physics P3 Q4" — zero vectors needed
create or replace function lookup_document(
  f_subject text,
  f_year int default null,
  f_school text default null,
  f_paper int default null,
  f_question int default null,
  f_type text default null
) returns setof documents language sql stable as $$
  select * from documents
  where subject = f_subject
    and (f_year     is null or year = f_year)
    and (f_school   is null or school = f_school)
    and (f_paper    is null or paper = f_paper)
    and (f_question is null or question = f_question)
    and (f_type     is null or type = f_type)
  limit 20;
$$;

-- one-hop graph expansion for a set of document ids
create or replace function expand_graph(
  doc_ids text[],
  rels text[] default array['explained_by','similar'],
  max_neighbors int default 6
) returns table (src text, dst text, rel text, w real) language sql stable as $$
  select e.src, e.dst, e.rel, e.w
  from edges e
  where e.src = any(doc_ids) and e.rel = any(rels)
  order by e.w desc
  limit max_neighbors;
$$;

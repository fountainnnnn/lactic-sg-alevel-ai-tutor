-- pgvector for embeddings, pg_trgm for fuzzy structured lookup
create extension if not exists vector;
create extension if not exists pg_trgm;
-- ============================================================
-- documents: one row per atomic vault note
-- ============================================================
create table documents (
  id text primary key,
  type text not null check (type in (
    'syllabus_section','reference','textbook_section',
    'specimen_question','specimen_mark_scheme',
    'prelim_question','prelim_mark_scheme','topic_hub'
  )),
  subject text,
  syllabus_code text,
  year int,
  school text,
  paper int,
  question int,
  topics text[] not null default '{}',
  syllabus_refs text[] not null default '{}',
  prereq_topics text[] not null default '{}',
  difficulty smallint check (difficulty between 1 and 5),
  license text not null check (license in (
    'cc_by','seab_reference','school_prelim','textbook_openstax'
  )),
  verbatim_safe boolean not null default false,
  hyde_questions text[] not null default '{}',
  summary text,
  keywords text[] not null default '{}',
  source_pdf text,
  source_pdf_page int,
  raw_markdown text not null,
  updated_at timestamptz not null default now()
);

create index documents_subject_year on documents(subject, year);
create index documents_type on documents(type);
create index documents_school on documents(school) where school is not null;
create index documents_topics on documents using gin(topics);
create index documents_kw on documents using gin(keywords);
create index documents_trgm on documents using gin (raw_markdown gin_trgm_ops);

-- ============================================================
-- chunks: embeddable pieces, 3 embedding views per chunk
-- ============================================================
create table chunks (
  id text primary key,
  document_id text not null references documents(id) on delete cascade,
  heading_path text,
  content text not null,
  content_hash text not null,
  embedding_content vector(1024),
  embedding_summary vector(1024),
  embedding_hyde    vector(1024),
  tsv tsvector generated always as (to_tsvector('english', content)) stored
);

create index chunks_doc on chunks(document_id);
create index chunks_hash on chunks(content_hash);
create index chunks_ec on chunks using ivfflat (embedding_content vector_cosine_ops) with (lists = 100);
create index chunks_es on chunks using ivfflat (embedding_summary vector_cosine_ops) with (lists = 100);
create index chunks_eh on chunks using ivfflat (embedding_hyde    vector_cosine_ops) with (lists = 100);
create index chunks_tsv_gin on chunks using gin (tsv);

-- ============================================================
-- edges: typed knowledge graph between documents
-- ============================================================
create table edges (
  src text not null references documents(id) on delete cascade,
  dst text not null references documents(id) on delete cascade,
  rel text not null check (rel in (
    'covers_syllabus','topic','explained_by','similar','requires_prereq'
  )),
  w real not null default 1.0,
  primary key (src, dst, rel)
);
create index edges_src on edges(src, rel);
create index edges_dst on edges(dst, rel);
-- ============================================================
-- conversations / messages (memory.md lives on-device, NOT here)
-- ============================================================
create table conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  created_at timestamptz not null default now()
);
create index conversations_user on conversations(user_id, created_at desc);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  role text not null check (role in ('user','assistant','system','tool')),
  content text not null,
  tool_name text,
  citations jsonb,
  model text,
  thinking_tokens int,
  cache_hit_ratio real,
  trace jsonb,
  created_at timestamptz not null default now()
);
create index messages_conv on messages(conversation_id, created_at);

-- ============================================================
-- RLS
-- ============================================================
alter table conversations enable row level security;
alter table messages enable row level security;
alter table documents enable row level security;
alter table chunks enable row level security;
alter table edges enable row level security;

-- users own their conversations
create policy conversations_own on conversations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy messages_own on messages
  for all using (
    exists (select 1 from conversations c
            where c.id = conversation_id and c.user_id = auth.uid())
  ) with check (
    exists (select 1 from conversations c
            where c.id = conversation_id and c.user_id = auth.uid())
  );

-- knowledge base is public-read; writes only via service role (bypasses RLS)
create policy documents_read on documents for select using (true);
create policy chunks_read    on chunks    for select using (true);
create policy edges_read     on edges     for select using (true);
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

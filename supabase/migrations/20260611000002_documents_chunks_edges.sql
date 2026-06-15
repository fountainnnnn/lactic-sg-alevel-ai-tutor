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

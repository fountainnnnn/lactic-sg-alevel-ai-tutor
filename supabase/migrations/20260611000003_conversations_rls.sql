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

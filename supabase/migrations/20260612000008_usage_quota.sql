-- Per-turn usage log (cost/latency telemetry) + quota counter for rate limiting.
-- Written by the service role only; users can read their own rows.

create table if not exists usage_log (
  id bigint generated always as identity primary key,
  user_id uuid,                          -- null only for ALLOW_ANON dev turns
  conversation_id uuid,
  model text,                            -- role tier: fast | deep | escalate | deep-web
  intent text,
  llm_calls smallint,
  prompt_tokens int,
  completion_tokens int,
  cost_usd numeric(10, 6),
  latency_ms int,
  web_search boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists usage_log_user_time on usage_log (user_id, created_at desc);

alter table usage_log enable row level security;

drop policy if exists "read own usage" on usage_log;
create policy "read own usage" on usage_log
  for select using (auth.uid() = user_id);
-- no insert/update/delete policies: only the service role writes

-- One round-trip quota check: turns in the last minute and last 24h.
create or replace function quota_counts(p_user uuid)
returns table (minute_ct int, day_ct int)
language sql stable
set search_path = public
as $$
  select
    count(*) filter (where created_at > now() - interval '1 minute')::int,
    count(*)::int
  from usage_log
  where user_id = p_user
    and created_at > now() - interval '24 hours';
$$;

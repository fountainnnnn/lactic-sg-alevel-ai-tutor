-- Switch the per-user DAILY allowance from a turn COUNT to a TOKEN budget.
-- Rationale: a casual chat (~4k tokens) costs a fraction of a retrieval-heavy
-- solve (~14k tokens), so a flat "N messages/day" cap overcharges light users
-- and undercharges heavy ones. Counting tokens makes the allowance fair and
-- proportional to actual cost. The per-minute count + the global monthly $ breaker
-- are unchanged (they govern burst + aggregate spend, not per-user fairness).
--
-- Adds day_tokens (prompt+completion over the rolling 24h) to usage_limits().
-- Existing columns keep their positions; callers read by name, so this is
-- backward-compatible apart from the new daily gate in the Edge Functions.

drop function if exists usage_limits(uuid, text, text);

create or replace function usage_limits(p_user uuid, p_device text default null, p_ip text default null)
returns table (
  minute_ct int, day_ct int, month_cost numeric,
  device_day_ct int, ip_day_ct int, day_tokens bigint
)
language sql stable security definer set search_path = public
as $$
  select
    coalesce((select count(*) from usage_log
              where user_id = p_user and created_at > now() - interval '1 minute'), 0)::int,
    coalesce((select count(*) from usage_log
              where user_id = p_user and created_at > now() - interval '24 hours'), 0)::int,
    coalesce((select sum(cost_usd) from usage_log
              where created_at >= date_trunc('month', now())), 0)::numeric,
    coalesce((select count(*) from usage_log
              where p_device is not null and device_id = p_device
                and user_id is null and created_at > now() - interval '24 hours'), 0)::int,
    coalesce((select count(*) from usage_log
              where p_ip is not null and ip = p_ip
                and user_id is null and created_at > now() - interval '24 hours'), 0)::int,
    coalesce((select sum(coalesce(prompt_tokens, 0) + coalesce(completion_tokens, 0))
              from usage_log
              where user_id = p_user and created_at > now() - interval '24 hours'), 0)::bigint;
$$;

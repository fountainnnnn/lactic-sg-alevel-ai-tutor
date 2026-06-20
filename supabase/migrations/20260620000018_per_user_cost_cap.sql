-- Per-user MONTHLY cost guardrail so a paying user can NEVER cost more than they
-- pay. The global $ breaker (month_cost vs MONTHLY_BUDGET_USD) caps aggregate
-- spend but has no per-user ceiling: a single heavy Plus/Max user on Gemini can
-- out-cost their subscription. This adds the per-user month-to-date spend so the
-- Edge Function can degrade that user to the cheap model (soft) and, past a hard
-- ceiling, stop further paid turns until the calendar month resets.
--
-- Adds user_month_cost (this user's spend since the start of the calendar month)
-- to usage_limits(). Existing columns keep their positions; callers read by name.

drop function if exists usage_limits(uuid, text, text);

create or replace function usage_limits(p_user uuid, p_device text default null, p_ip text default null)
returns table (
  minute_ct int, day_ct int, month_cost numeric,
  device_day_ct int, ip_day_ct int, day_tokens bigint,
  user_month_cost numeric
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
              where user_id = p_user and created_at > now() - interval '24 hours'), 0)::bigint,
    coalesce((select sum(cost_usd) from usage_log
              where user_id = p_user and created_at >= date_trunc('month', now())), 0)::numeric;
$$;

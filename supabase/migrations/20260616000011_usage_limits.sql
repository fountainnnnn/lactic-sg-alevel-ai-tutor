-- One round-trip for both gatekeepers: per-user rate counts (minute/day) AND
-- the GLOBAL month-to-date spend (for the budget circuit-breaker). Global spend
-- is computed for every turn, including anon; per-user counts only when p_user
-- is supplied.

create or replace function usage_limits(p_user uuid)
returns table (minute_ct int, day_ct int, month_cost numeric)
language sql stable security definer set search_path = public
as $$
  select
    coalesce((select count(*) from usage_log
              where user_id = p_user and created_at > now() - interval '1 minute'), 0)::int,
    coalesce((select count(*) from usage_log
              where user_id = p_user and created_at > now() - interval '24 hours'), 0)::int,
    coalesce((select sum(cost_usd) from usage_log
              where created_at >= date_trunc('month', now())), 0)::numeric;
$$;

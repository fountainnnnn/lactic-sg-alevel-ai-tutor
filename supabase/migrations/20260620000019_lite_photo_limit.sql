-- Give Lite a limited "taste" of photo solve (default 2/day, enforced in the
-- chat Edge Function), with Plus+ unlimited. Needs a per-user daily count of
-- photo turns. Mark photo turns in usage_log and surface photo_day_ct from the
-- usage_limits() RPC alongside the existing counters.

alter table usage_log add column if not exists photo boolean not null default false;

drop function if exists usage_limits(uuid, text, text);

create or replace function usage_limits(p_user uuid, p_device text default null, p_ip text default null)
returns table (
  minute_ct int, day_ct int, month_cost numeric,
  device_day_ct int, ip_day_ct int, day_tokens bigint,
  user_month_cost numeric, photo_day_ct int
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
              where user_id = p_user and created_at >= date_trunc('month', now())), 0)::numeric,
    coalesce((select count(*) from usage_log
              where user_id = p_user and photo and created_at > now() - interval '24 hours'), 0)::int;
$$;

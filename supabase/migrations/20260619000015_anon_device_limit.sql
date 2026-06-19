-- Anonymous daily cap, keyed by device. Anon turns have no user_id, so they
-- went uncounted (no per-user limit). Log a device_id on each turn and count it
-- so anonymous users get a small free taste (default 5/day) that nudges sign-up.
-- This is friction, not a security boundary (a user can reset the device id by
-- clearing app data) — that's fine for a sign-up nudge.

alter table usage_log add column if not exists device_id text;
create index if not exists usage_log_device_time on usage_log (device_id, created_at desc);

-- Replace the 1-arg gatekeeper with a 2-arg version that also returns today's
-- anonymous turn count for this device.
drop function if exists usage_limits(uuid);

create or replace function usage_limits(p_user uuid, p_device text default null)
returns table (minute_ct int, day_ct int, month_cost numeric, device_day_ct int)
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
                and user_id is null and created_at > now() - interval '24 hours'), 0)::int;
$$;

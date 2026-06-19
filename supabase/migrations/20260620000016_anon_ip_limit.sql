-- Reinstall-proof anonymous limiting. The device id resets on uninstall, so a
-- device-only cap can be farmed by reinstalling. Add an IP-based cap that
-- survives reinstall/device-id rotation. Effective anon limit = blocked when
-- EITHER the device OR the IP exceeds its daily cap. IP cap is generous so a
-- shared school/library network nudges extras to sign up rather than hard-walling.

alter table usage_log add column if not exists ip text;
create index if not exists usage_log_ip_time on usage_log (ip, created_at desc);

drop function if exists usage_limits(uuid, text);

create or replace function usage_limits(p_user uuid, p_device text default null, p_ip text default null)
returns table (minute_ct int, day_ct int, month_cost numeric, device_day_ct int, ip_day_ct int)
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
                and user_id is null and created_at > now() - interval '24 hours'), 0)::int;
$$;

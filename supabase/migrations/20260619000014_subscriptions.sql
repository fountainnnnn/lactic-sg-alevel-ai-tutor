-- Server-side subscription state, written by the RevenueCat webhook
-- (functions/revenuecat-webhook). This is the SOURCE OF TRUTH for premium:
-- the chat function reads it instead of trusting the client `premium` flag.

create table if not exists public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  rc_app_user_id text,
  entitlements text[] not null default '{}', -- active entitlement identifiers
  tier text,                                  -- 'plus' | 'unlimited' | null
  product_id text,
  store text,
  expires_at timestamptz,                     -- null = no expiry (promo/lifetime)
  is_active boolean not null default false,
  updated_at timestamptz not null default now(),
  raw jsonb
);

alter table public.subscriptions enable row level security;

-- A user may read only their own row. Writes are service-role only (the webhook
-- uses the service role, which bypasses RLS) — there is intentionally no
-- insert/update policy for end users.
create policy "subscriptions_select_own"
  on public.subscriptions for select to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.subscriptions to authenticated;

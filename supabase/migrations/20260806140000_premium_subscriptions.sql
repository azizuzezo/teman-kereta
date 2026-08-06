-- Premium subscriptions: gates the "reminder N stasiun sebelum tujuan"
-- notification (ActiveTripController.showStopAlert) behind a paid tier, with
-- a one-time 14-day free trial per device (not per account) at first sign-up.
-- User's own request: "featrue notify or reminder station is being Premium
-- feature... free trial 14 days and if the user 1 device then change
-- acount, will not get a free." Payment itself goes through the user's own
-- GoPay/Midtrans merchant gateway (Edge Functions premium-create-payment/
-- premium-check-payment call it directly — this migration is schema only).

create table public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'none'
    check (status in ('trialing', 'active', 'expired', 'none')),
  trial_ends_at timestamptz,
  current_period_end timestamptz,
  updated_at timestamptz not null default now()
);

comment on table public.subscriptions is
  'One row per user: entitlement state for the premium station-reminder feature. Written only by claim_trial() and the premium-check-payment Edge Function (service_role) — never directly by the client.';

alter table public.subscriptions enable row level security;

create policy "Users can read their own subscription"
  on public.subscriptions for select
  using (auth.uid() = user_id);

grant select on public.subscriptions to authenticated;
grant select, insert, update, delete on public.subscriptions to service_role;

create trigger subscriptions_set_updated_at before update on public.subscriptions
  for each row execute function public.set_updated_at();

-- Ties the free trial to one physical device (Android ID from the Flutter
-- app), regardless of how many accounts get created on it afterward.
-- Deliberately no client-readable policy — only claim_trial()'s
-- SECURITY DEFINER body and service_role ever touch this table.
create table public.device_trial_claims (
  device_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now()
);

comment on table public.device_trial_claims is
  'Best-effort anti-abuse: one free trial per Android ID, ever. Not foolproof (ANDROID_ID resets on factory reset, a different device sidesteps it entirely) — deliberately accepted as "raises the bar for casual abuse," not "impossible to abuse," per the product decision behind this feature.';

alter table public.device_trial_claims enable row level security;
grant select, insert, update, delete on public.device_trial_claims to service_role;

-- Real payment attempts against the GoPay gateway.
create table public.premium_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  qris_id text not null,
  trx_id text,
  amount integer not null,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'expired', 'cancelled')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  paid_at timestamptz
);

comment on table public.premium_payments is
  'One row per QRIS payment attempt created via the premium-create-payment Edge Function. amount includes a small random offset (see that function) on top of app_config.remote_config.premium_price_idr, so two riders paying the same nominal price in the same window still resolve to distinct QR codes/amounts against the gateway''s amount-based matching.';

alter table public.premium_payments enable row level security;

create policy "Users can read their own payments"
  on public.premium_payments for select
  using (auth.uid() = user_id);

grant select on public.premium_payments to authenticated;
grant select, insert, update, delete on public.premium_payments to service_role;

create index premium_payments_qris_id_idx on public.premium_payments (qris_id);
create index premium_payments_user_status_idx on public.premium_payments (user_id, status);

-- Grants a 14-day free trial once per device, ever. Runs as the calling
-- user (auth.uid()) — called right after a real sign-up completes.
-- Idempotent: a second call for an already-subscribed user just returns
-- their existing row rather than erroring or granting a second trial.
create function public.claim_trial(p_device_id text)
returns public.subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing public.subscriptions;
  v_device_claimed boolean;
  v_result public.subscriptions;
begin
  if v_user_id is null then
    raise exception 'claim_trial() requires an authenticated user';
  end if;

  if p_device_id is null or length(trim(p_device_id)) = 0 then
    raise exception 'claim_trial() requires a non-empty device id';
  end if;

  select * into v_existing from public.subscriptions where user_id = v_user_id;
  if found then
    return v_existing;
  end if;

  select exists(
    select 1 from public.device_trial_claims where device_id = p_device_id
  ) into v_device_claimed;

  if v_device_claimed then
    insert into public.subscriptions (user_id, status)
    values (v_user_id, 'none')
    returning * into v_result;
  else
    insert into public.subscriptions (user_id, status, trial_ends_at)
    values (v_user_id, 'trialing', now() + interval '14 days')
    returning * into v_result;
    insert into public.device_trial_claims (device_id, user_id)
    values (p_device_id, v_user_id);
  end if;

  return v_result;
end;
$$;

grant execute on function public.claim_trial(text) to authenticated;

-- Live entitlement updates in the Flutter app (paywall page + the
-- station-reminder gate) — same publication pattern already used for
-- app_config's maintenance-mode toggle. replica identity full matches the
-- convention set for every other Realtime-consumed table in this schema
-- (vehicle_positions/trip_updates/service_alerts/etc. — see
-- 20260804130000_initial_schema.sql).
alter table public.subscriptions replica identity full;
alter publication supabase_realtime add table public.subscriptions;

-- Seed pricing into the existing remote_config key so it's admin-editable
-- (via the admin panel's Settings page) without an app update — closes the
-- "remote_config seeded but never used" gap that's existed since app_config
-- was first built.
update public.app_config
set value = coalesce(value, '{}'::jsonb) || jsonb_build_object(
  'premium_price_idr', 15000,
  'premium_period_days', 30,
  'premium_trial_days', 14
)
where key = 'remote_config';

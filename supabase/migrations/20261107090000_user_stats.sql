-- Aggregate user counts. Counts only, no personal data.
--  * public_user_stats(): callable by the landing page (anon) -> registered accounts.
--  * admin_user_stats(): service_role only -> registered, installed devices, active users.
-- "Installed devices" = distinct devices that opened the app signed-in and registered
-- a push token (device_tokens). There is no APK download counter, so this is the
-- closest real number. "Active" = device_tokens.updated_at, refreshed on each app open.

create or replace function public.public_user_stats()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'registered_users', (select count(*) from auth.users where is_anonymous = false)
  );
$$;

revoke all on function public.public_user_stats() from public;
grant execute on function public.public_user_stats() to anon, authenticated, service_role;

create or replace function public.admin_user_stats()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'registered_users', (select count(*) from auth.users where is_anonymous = false),
    'installed_devices', (select count(distinct device_id) from public.device_tokens),
    'users_with_device', (select count(distinct user_id) from public.device_tokens),
    'active_24h', (select count(distinct user_id) from public.device_tokens where updated_at > now() - interval '1 day'),
    'active_7d',  (select count(distinct user_id) from public.device_tokens where updated_at > now() - interval '7 days'),
    'active_30d', (select count(distinct user_id) from public.device_tokens where updated_at > now() - interval '30 days')
  );
$$;

revoke all on function public.admin_user_stats() from public, anon, authenticated;
grant execute on function public.admin_user_stats() to service_role;

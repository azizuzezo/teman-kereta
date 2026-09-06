-- Consolidate public.profiles into public.users (the original, canonical user table).
--
-- public.profiles was added later (20260806160000/20260806170000) solely to support
-- premium (is_premium) + an "all users" admin view, but its signup trigger was named
-- on_auth_user_created -- the SAME NAME as the original trigger that populates
-- public.users -- so creating it silently replaced the original trigger. Since that
-- migration ran, new signups have only been inserted into public.profiles, not
-- public.users, even though most of the app (device_tokens, user_favorites,
-- commute_plans, etc.) foreign-keys against public.users. This migration restores a
-- single source of truth and backfills any rows that were missed as a result.

-- 1. Add columns this app now needs directly on public.users.
alter table public.users
  add column if not exists username text,
  add column if not exists follower_count integer not null default 0,
  add column if not exists following_count integer not null default 0;

alter table public.users
  drop constraint if exists users_username_format;
alter table public.users
  add constraint users_username_format
    check (username is null or username ~ '^[a-z0-9_]{3,20}$');

create unique index if not exists users_username_lower_unique_idx
  on public.users (lower(username)) where username is not null;

grant update (display_name, avatar_url, username) on table public.users to authenticated;

-- 2. Backfill: any auth.users row missing from public.users (caused by the clobbered
--    trigger above) gets a row now, preferring data already captured in profiles.
insert into public.users (id, display_name, email, avatar_url, created_at, updated_at)
select
  u.id,
  coalesce(p.full_name, u.raw_user_meta_data ->> 'display_name', u.raw_user_meta_data ->> 'full_name',
           split_part(u.email, '@', 1)),
  u.email,
  nullif(u.raw_user_meta_data ->> 'avatar_url', ''),
  u.created_at,
  now()
from auth.users u
left join public.profiles p on p.id = u.id
where u.is_anonymous = false
  and not exists (select 1 from public.users existing where existing.id = u.id)
on conflict (id) do nothing;

-- 3. Backfill display_name on existing public.users rows from profiles.full_name
--    where users never got a display name of its own.
update public.users u
set display_name = p.full_name
from public.profiles p
where u.id = p.id
  and u.display_name is null
  and p.full_name is not null;

-- 4. Restore the original signup trigger (populate public.users), removing the
--    profiles-populating one that clobbered it.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

drop trigger if exists on_auth_user_email_updated on auth.users;
-- on_auth_user_email_changed (updates public.users.email) already exists from the
-- original schema and was never touched by the profiles migration -- no need to
-- recreate it here.

drop function if exists public.handle_new_user();
drop function if exists public.handle_user_email_change();

-- 5. Repoint the admin "all users" view at public.users instead of public.profiles,
--    dropping premium-only columns (the premium tables themselves are removed in a
--    separate, explicitly-confirmed migration).
drop view if exists public.admin_subscribers_view;

create or replace view public.admin_all_users_view as
select
  u.id                                                                        as user_id,
  coalesce(pu.display_name, u.raw_user_meta_data ->> 'display_name',
           split_part(u.email, '@', 1), 'Pengguna Teman Kereta')              as full_name,
  coalesce(pu.email, u.email, 'Belum ada email')                              as email,
  pu.username,
  u.created_at                                                                as registered_at,
  u.last_sign_in_at
from auth.users u
left join public.users pu on pu.id = u.id
where u.is_anonymous = false
order by u.created_at desc;

grant select on public.admin_all_users_view to service_role;

-- 6. profiles no longer has any reason to exist.
drop table if exists public.profiles;

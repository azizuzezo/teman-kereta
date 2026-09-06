-- Auto-create a profiles row when a new user signs up.
-- This ensures all registered users appear in the admin panel,
-- not just those who have activated trial or premium.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, is_premium, created_at, updated_at)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'display_name',
      new.raw_user_meta_data->>'full_name',
      split_part(new.email, '@', 1)
    ),
    false,
    now(),
    now()
  )
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();
  return new;
end;
$$;

-- Drop existing trigger if any, then recreate.
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Also update profiles on email change.
create or replace function public.handle_user_email_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.profiles
    set email = new.email,
        updated_at = now()
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_updated on auth.users;

create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row execute procedure public.handle_user_email_change();

-- Update admin_subscribers_view to show ALL registered users (not just subscribers).
create or replace view public.admin_all_users_view as
select
  u.id                                                          as user_id,
  coalesce(p.full_name, u.raw_user_meta_data->>'display_name',
           split_part(u.email, '@', 1), 'Pengguna Teman Kereta') as full_name,
  coalesce(p.email, u.email, 'Belum ada email')                as email,
  u.created_at                                                  as registered_at,
  u.last_sign_in_at,
  coalesce(s.status, 'none')                                   as sub_status,
  s.trial_ends_at,
  s.current_period_end,
  s.updated_at                                                  as sub_updated_at,
  p.is_premium
from auth.users u
left join public.profiles p on u.id = p.id
left join public.subscriptions s on u.id = s.user_id
where u.is_anonymous = false
order by u.created_at desc;

grant select on public.admin_all_users_view to service_role;

-- Back-fill profiles for existing users who signed up before this trigger existed.
insert into public.profiles (id, email, full_name, is_premium, created_at, updated_at)
select
  u.id,
  u.email,
  coalesce(u.raw_user_meta_data->>'display_name', u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1)),
  coalesce((select is_premium from public.profiles where id = u.id), false),
  u.created_at,
  now()
from auth.users u
where u.is_anonymous = false
on conflict (id) do nothing;

-- Create profiles table if it does not exist yet
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  is_premium boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.profiles to service_role;

-- Add user_name and user_email columns to public.subscriptions for Admin Panel display
alter table public.subscriptions add column if not exists user_name text;
alter table public.subscriptions add column if not exists user_email text;

comment on column public.subscriptions.user_name is 'Full name of the subscriber for Admin Panel display';
comment on column public.subscriptions.user_email is 'Email address of the subscriber for Admin Panel display';

-- Create or update admin view for user subscribers list
create or replace view public.admin_subscribers_view as
select 
  s.user_id,
  coalesce(s.user_name, p.full_name, 'Pengguna Teman Kereta') as full_name,
  coalesce(s.user_email, p.email, u.email, 'Belum ada email') as email,
  s.status,
  s.trial_ends_at,
  s.current_period_end,
  s.updated_at
from public.subscriptions s
left join public.profiles p on s.user_id = p.id
left join auth.users u on s.user_id = u.id;

grant select on public.admin_subscribers_view to service_role;
grant select on public.admin_subscribers_view to authenticated;

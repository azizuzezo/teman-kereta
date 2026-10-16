-- Google Play requirements for apps with accounts and user-generated content:
--   * in-app account deletion (delete_my_account)
--   * a way to report objectionable content (forum_reports)
--   * a way to block abusive users (user_blocks)

-- ---------------------------------------------------------------------------
-- Account deletion
-- ---------------------------------------------------------------------------
-- Deleting the auth.users row cascades to public.users and from there to
-- preferences, favorites, device tokens, follows, forum posts/comments/likes
-- (all declared `on delete cascade`). Files in storage buckets are removed by
-- the app before calling this (storage owners can delete their own objects).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_uid uuid := auth.uid();
begin
  if current_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  delete from auth.users where id = current_uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

comment on function public.delete_my_account() is
  'Permanently deletes the calling user''s account and, through ON DELETE CASCADE, all of their data.';

-- ---------------------------------------------------------------------------
-- Forum reports
-- ---------------------------------------------------------------------------
create table public.forum_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id) on delete cascade,
  post_id uuid references public.forum_posts (id) on delete cascade,
  comment_id uuid references public.forum_comments (id) on delete cascade,
  reason text not null
    check (reason in ('spam', 'harassment', 'inappropriate', 'misinformation', 'other')),
  details text check (details is null or char_length(details) <= 500),
  status text not null default 'open'
    check (status in ('open', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now(),
  check (((post_id is not null)::int + (comment_id is not null)::int) = 1)
);

-- One report per reporter per target; re-reporting is a no-op for the app.
create unique index forum_reports_reporter_post_idx
  on public.forum_reports (reporter_id, post_id) where post_id is not null;
create unique index forum_reports_reporter_comment_idx
  on public.forum_reports (reporter_id, comment_id) where comment_id is not null;
create index forum_reports_status_created_idx
  on public.forum_reports (status, created_at desc);

alter table public.forum_reports enable row level security;

create policy "Users can file their own reports"
  on public.forum_reports for insert to authenticated
  with check (auth.uid() = reporter_id);

create policy "Users can read their own reports"
  on public.forum_reports for select to authenticated
  using (auth.uid() = reporter_id);

grant select, insert on public.forum_reports to authenticated;
grant select, insert, update, delete on public.forum_reports to service_role;

-- ---------------------------------------------------------------------------
-- User blocks
-- ---------------------------------------------------------------------------
create table public.user_blocks (
  blocker_id uuid not null references public.users (id) on delete cascade,
  blocked_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.user_blocks enable row level security;

create policy "Users can read their own blocks"
  on public.user_blocks for select to authenticated
  using (auth.uid() = blocker_id);

create policy "Users can block others"
  on public.user_blocks for insert to authenticated
  with check (auth.uid() = blocker_id);

create policy "Users can unblock"
  on public.user_blocks for delete to authenticated
  using (auth.uid() = blocker_id);

grant select, insert, delete on public.user_blocks to authenticated;
grant select, insert, update, delete on public.user_blocks to service_role;

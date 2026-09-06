-- Forum (posts/comments/likes), follow system, and Storage buckets for
-- avatars + forum post images. Additive only -- no drops.

-- Storage buckets (public read, owner-only write via RLS below).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('forum-post-images', 'forum-post-images', true, 8388608, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy "Public can read avatars"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "Owners can write their own avatar"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Owners can update their own avatar"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Owners can delete their own avatar"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Public can read forum post images"
  on storage.objects for select
  using (bucket_id = 'forum-post-images');

create policy "Owners can write their own forum images"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'forum-post-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Owners can delete their own forum images"
  on storage.objects for delete to authenticated
  using (bucket_id = 'forum-post-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- Follow system.
create table public.user_follows (
  follower_id uuid not null references public.users(id) on delete cascade,
  followee_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

alter table public.user_follows enable row level security;

create policy "Anyone can read follows"
  on public.user_follows for select
  using (true);

create policy "Users manage their own follow rows"
  on public.user_follows for insert to authenticated
  with check (auth.uid() = follower_id);

create policy "Users can unfollow"
  on public.user_follows for delete to authenticated
  using (auth.uid() = follower_id);

grant select on public.user_follows to anon, authenticated;
grant insert, delete on public.user_follows to authenticated;

create function public.handle_follow_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.users set following_count = following_count + 1 where id = new.follower_id;
    update public.users set follower_count = follower_count + 1 where id = new.followee_id;
  elsif tg_op = 'DELETE' then
    update public.users set following_count = greatest(following_count - 1, 0) where id = old.follower_id;
    update public.users set follower_count = greatest(follower_count - 1, 0) where id = old.followee_id;
  end if;
  return null;
end;
$$;

create trigger user_follows_bump_counts
  after insert or delete on public.user_follows
  for each row execute function public.handle_follow_change();

create index users_username_search_idx on public.users using gin (username extensions.gin_trgm_ops);

-- Forum.
create table public.forum_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  image_url text,
  line_id uuid references public.lines(id) on delete set null,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  status text not null default 'visible' check (status in ('visible','hidden','removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.forum_posts enable row level security;

create policy "Anyone can read visible posts"
  on public.forum_posts for select
  using (status = 'visible');

create policy "Owners can read their own non-visible posts"
  on public.forum_posts for select to authenticated
  using (auth.uid() = user_id);

create policy "Users can create their own posts"
  on public.forum_posts for insert to authenticated
  with check (auth.uid() = user_id);

create policy "Owners can update their own posts"
  on public.forum_posts for update to authenticated
  using (auth.uid() = user_id);

create policy "Owners can delete their own posts"
  on public.forum_posts for delete to authenticated
  using (auth.uid() = user_id);

grant select on public.forum_posts to anon, authenticated;
grant insert on public.forum_posts to authenticated;
grant update (body, image_url, line_id) on public.forum_posts to authenticated;
grant delete on public.forum_posts to authenticated;
grant select, insert, update, delete on public.forum_posts to service_role;

create trigger forum_posts_set_updated_at before update on public.forum_posts
  for each row execute function public.set_updated_at();

create index forum_posts_created_at_idx on public.forum_posts (created_at desc) where status = 'visible';
create index forum_posts_user_id_idx on public.forum_posts (user_id);

create table public.forum_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.forum_posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  status text not null default 'visible' check (status in ('visible','hidden','removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.forum_comments enable row level security;

create policy "Anyone can read visible comments"
  on public.forum_comments for select
  using (status = 'visible');

create policy "Users can create their own comments"
  on public.forum_comments for insert to authenticated
  with check (auth.uid() = user_id);

create policy "Owners can update their own comments"
  on public.forum_comments for update to authenticated
  using (auth.uid() = user_id);

create policy "Owners can delete their own comments"
  on public.forum_comments for delete to authenticated
  using (auth.uid() = user_id);

grant select on public.forum_comments to anon, authenticated;
grant insert on public.forum_comments to authenticated;
grant update (body) on public.forum_comments to authenticated;
grant delete on public.forum_comments to authenticated;
grant select, insert, update, delete on public.forum_comments to service_role;

create trigger forum_comments_set_updated_at before update on public.forum_comments
  for each row execute function public.set_updated_at();

create index forum_comments_post_id_idx on public.forum_comments (post_id);

create table public.forum_likes (
  post_id uuid not null references public.forum_posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.forum_likes enable row level security;

create policy "Anyone can read likes"
  on public.forum_likes for select
  using (true);

create policy "Users manage their own likes"
  on public.forum_likes for insert to authenticated
  with check (auth.uid() = user_id);

create policy "Users can unlike"
  on public.forum_likes for delete to authenticated
  using (auth.uid() = user_id);

grant select on public.forum_likes to anon, authenticated;
grant insert, delete on public.forum_likes to authenticated;

create function public.handle_forum_like_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.forum_posts set like_count = like_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update public.forum_posts set like_count = greatest(like_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$;

create trigger forum_likes_bump_count
  after insert or delete on public.forum_likes
  for each row execute function public.handle_forum_like_change();

create function public.handle_forum_comment_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'visible' then
    update public.forum_posts set comment_count = comment_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' and old.status = 'visible' then
    update public.forum_posts set comment_count = greatest(comment_count - 1, 0) where id = old.post_id;
  elsif tg_op = 'UPDATE' and old.status = 'visible' and new.status <> 'visible' then
    update public.forum_posts set comment_count = greatest(comment_count - 1, 0) where id = new.post_id;
  elsif tg_op = 'UPDATE' and old.status <> 'visible' and new.status = 'visible' then
    update public.forum_posts set comment_count = comment_count + 1 where id = new.post_id;
  end if;
  return null;
end;
$$;

create trigger forum_comments_bump_count
  after insert or update or delete on public.forum_comments
  for each row execute function public.handle_forum_comment_change();

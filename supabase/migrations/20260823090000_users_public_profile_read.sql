-- public.users only ever had an RLS policy for a user to read their OWN
-- row, and no table-level GRANT to anon/authenticated at all -- fine for
-- the original personal-data-only app, but the forum/follow/social
-- features added since then need to read OTHER users' public profile
-- info (username, display_name, avatar_url, follower/following counts)
-- to show post authors, comment authors, search results, etc. Column-
-- restricted grant keeps email and other non-public fields hidden from
-- everyone except the row's own owner and service_role.

grant select (id, username, display_name, avatar_url, follower_count, following_count)
  on public.users to anon, authenticated;

create policy "Anyone can read public profile fields"
  on public.users for select
  using (true);

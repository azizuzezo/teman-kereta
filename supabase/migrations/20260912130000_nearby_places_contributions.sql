-- Lets community members actually submit nearby-place suggestions (the
-- "Tambah Tempat" flow in explore_page.dart) -- the table previously had
-- only a read grant for anon/authenticated, so every insert from the app
-- silently failed under RLS while the UI still showed a success toast.
-- Adds real ownership (so a submission is attributable/moderatable) and a
-- storage bucket for a real photo, mirroring the forum-post-images pattern.

alter table public.nearby_places
  add column submitted_by uuid references public.users (id) on delete set null;

create index nearby_places_submitted_by_idx on public.nearby_places (submitted_by);

create policy "Users can submit their own nearby places"
  on public.nearby_places for insert to authenticated
  with check (auth.uid() = submitted_by);

grant insert on public.nearby_places to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('nearby-place-images', 'nearby-place-images', true, 8388608, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy "Public can read nearby place images"
  on storage.objects for select
  using (bucket_id = 'nearby-place-images');

create policy "Owners can write their own nearby place images"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'nearby-place-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Owners can delete their own nearby place images"
  on storage.objects for delete to authenticated
  using (bucket_id = 'nearby-place-images' and (storage.foldername(name))[1] = auth.uid()::text);

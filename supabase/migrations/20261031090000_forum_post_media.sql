-- Up to four photos or videos per forum post. Each item carries its own
-- dimensions so the feed can lay it out at its real aspect ratio (Threads
-- style) instead of cropping everything to one shape:
--   [{"url": "...", "type": "image" | "video", "width": 1080, "height": 1440,
--     "duration_ms": 12000}]
-- `image_url` stays for posts made before this and for older app builds;
-- readers treat it as a single-image `media` when `media` is empty.
alter table public.forum_posts
  add column media jsonb not null default '[]'::jsonb
  constraint forum_posts_media_shape
    check (jsonb_typeof(media) = 'array' and jsonb_array_length(media) <= 4);

-- Photos and videos together. 50 MB covers a 60 s phone video after the
-- app's own compression; the app enforces the 60 s limit before upload.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'forum-post-media',
  'forum-post-media',
  true,
  52428800,
  array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','video/webm']
)
on conflict (id) do nothing;

create policy "Public can read forum post media"
  on storage.objects for select
  using (bucket_id = 'forum-post-media');

create policy "Owners can write their own forum media"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'forum-post-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Owners can delete their own forum media"
  on storage.objects for delete to authenticated
  using (bucket_id = 'forum-post-media' and (storage.foldername(name))[1] = auth.uid()::text);

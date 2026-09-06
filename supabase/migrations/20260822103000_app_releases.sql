-- Self-hosted APK auto-update: a public, admin-writable table of published
-- releases, checked by the Flutter app on launch (sideload distribution,
-- no Play Store). Backed by the 'releases' Storage bucket for the APK file.

create table public.app_releases (
  id uuid primary key default gen_random_uuid(),
  version_code integer not null,
  version_name text not null,
  apk_url text not null,
  changelog text,
  min_supported_version_code integer,
  published_at timestamptz not null default now(),
  unique (version_code)
);

alter table public.app_releases enable row level security;

create policy "Anyone can read releases"
  on public.app_releases for select
  using (true);

grant select on public.app_releases to anon, authenticated;
grant select, insert, update, delete on public.app_releases to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('releases', 'releases', true, 209715200, array['application/vnd.android.package-archive'])
on conflict (id) do nothing;

create policy "Public can read release APKs"
  on storage.objects for select
  using (bucket_id = 'releases');

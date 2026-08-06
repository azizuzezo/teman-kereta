-- app_config was written admin-only (service_role) from the start, with an
-- explicit note that the Flutter app didn't read it yet — see
-- 20260805130000_admin_panel.sql's own table comment. This closes that gap
-- from the database side: read-only for anon/authenticated, matching the
-- existing "Public can read stations/lines/trips/..." policy shape.
create policy "Public can read app_config" on public.app_config
  for select to anon, authenticated using (true);

grant select on public.app_config to anon, authenticated;

comment on table public.app_config is
  'Key/value store for admin-configurable app behavior (PRD §36 "Mode maintenance" / "Remote configuration"). Read by the Flutter app via AppConfigController (lib/features/app_config) — writes remain service_role/admin-panel only.';

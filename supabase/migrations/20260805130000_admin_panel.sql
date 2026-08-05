-- ============================================================================
-- Schema additions backing the Next.js admin panel (`admin/`, PRD §36).
--
-- The admin panel never talks to Supabase with the anon/authenticated key —
-- all reads/writes to these tables (and to the existing reference tables:
-- operators/lines/stations/service_alerts/user_reports/nearby_places) happen
-- server-side with the SERVICE_ROLE key, matching this project's existing
-- "reference data writes go through a trusted server connection, not a
-- client" posture (see docs/backend-local.md). RLS is enabled on all three
-- new tables with NO anon/authenticated policies at all — client access is
-- denied by default; only the service-role connection (which bypasses RLS)
-- can touch them. Supabase Auth (email/password) is still used for the
-- admin's own login session, but "is this signed-in user actually an admin"
-- is checked server-side against `admin_users`, never via a client-visible
-- RLS policy.
-- ============================================================================

create table public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (display_name is null or char_length(display_name) between 1 and 80),
  created_at timestamptz not null default now()
);

comment on table public.admin_users is
  'Membership list for the admin panel — presence of a row grants admin access. Never exposed to anon/authenticated clients.';

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid references public.admin_users (user_id) on delete set null,
  action text not null check (action in ('create', 'update', 'delete')),
  table_name text not null,
  record_id text,
  changes jsonb,
  created_at timestamptz not null default now()
);

comment on table public.audit_log is
  'Append-only record of admin-panel writes (PRD §36 "Audit log"). Written by the same server action that performs the write, right after it succeeds.';

create index audit_log_created_idx on public.audit_log (created_at desc);
create index audit_log_table_record_idx on public.audit_log (table_name, record_id);

create table public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

comment on table public.app_config is
  'Key/value store for admin-configurable app behavior (PRD §36 "Mode maintenance" / "Remote configuration"). NOTE: as of this migration, the Flutter app does not read this table yet — editing it here has no effect on the mobile app until that read path is built. Tracked as a known gap in ENGINEERING.md.';

insert into public.app_config (key, value)
values
  ('maintenance_mode', 'false'::jsonb),
  ('remote_config', '{}'::jsonb);

create trigger app_config_set_updated_at before update on public.app_config
  for each row execute function public.set_updated_at();

alter table public.admin_users enable row level security;
alter table public.audit_log enable row level security;
alter table public.app_config enable row level security;

-- Deliberately no anon/authenticated policies on any of these three tables —
-- see the header comment. `grant` statements below exist only so the
-- service-role connection (which already bypasses RLS) has explicit table
-- privileges; PostgREST still requires them even for service_role.
grant select, insert, update, delete on public.admin_users to service_role;
grant select, insert, update, delete on public.audit_log to service_role;
grant select, insert, update, delete on public.app_config to service_role;

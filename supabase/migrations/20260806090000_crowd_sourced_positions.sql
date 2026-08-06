-- ============================================================================
-- Crowd-sourced vehicle positions.
--
-- Real riders, with explicit consent (bundled into the existing "Deteksi
-- Otomatis Naik KRL" setting — enabling that setting is what authorizes
-- this), report their own phone's GPS position while their Active Trip is
-- confirmed onBoard. This is NOT a third-party feed and NOT scraping
-- anyone's private infrastructure — it's this app's own users reporting
-- their own position, which they've consented to, same posture as every
-- other honesty rule in this project: never present anything as more
-- authoritative than it is (see `accuracy_status = 'near_real_time'` below,
-- not 'real_time' — a rider's own GPS is close to ground truth but delayed
-- by polling + aggregation, so it isn't instantaneous).
--
-- Keyed by (external_trip_id, service_date) rather than trips.id, since a
-- reporting client only reliably has the raw GTFS identifier pair in
-- common with every other client regardless of which provider
-- (`gtfs`/`local_supabase`) it's running — see ENGINEERING.md.
-- ============================================================================

create table public.crowd_position_reports (
  id uuid primary key default gen_random_uuid(),
  external_trip_id text not null check (char_length(external_trip_id) between 1 and 100),
  service_date date not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  reported_at timestamptz not null,
  -- A random per-install identifier, generated client-side, never tied to
  -- any real identity or account — exists only so the aggregation function
  -- can count *distinct reporters* per trip as a light anti-spoofing
  -- signal, not to identify who reported anything. Never selectable by
  -- anon/authenticated (see grants below) — only service_role reads it,
  -- and only reads the aggregate, not this table's raw rows.
  device_session_id text not null check (char_length(device_session_id) between 1 and 100),
  created_at timestamptz not null default now(),
  -- A report timestamped far in the past or the future is either stale
  -- client state or an attempt to backdate/spoof — reject it outright
  -- rather than storing and hoping the aggregation step filters it.
  check (reported_at between now() - interval '10 minutes' and now() + interval '2 minutes')
);

create index crowd_position_reports_trip_idx
  on public.crowd_position_reports (external_trip_id, service_date, reported_at desc);

alter table public.crowd_position_reports enable row level security;

-- Insert-only for anon/authenticated — this table is a write-only inbox.
-- Nobody reads it directly; `refresh_crowd_vehicle_positions()` (below)
-- reads it as `service_role` and folds it into `public.vehicle_positions`,
-- which is what every client actually queries.
create policy "Anyone can report their own position"
  on public.crowd_position_reports
  for insert
  to anon, authenticated
  with check (true);

revoke all on table public.crowd_position_reports from public;
grant insert on table public.crowd_position_reports to anon, authenticated;
grant all on table public.crowd_position_reports to service_role;

-- vehicle_positions.source gains 'crowd_sourced' alongside the existing
-- official_api/gtfs_realtime/estimated/demo values.
alter table public.vehicle_positions
  drop constraint vehicle_positions_source_check;
alter table public.vehicle_positions
  add constraint vehicle_positions_source_check
  check (source in ('official_api', 'gtfs_realtime', 'estimated', 'demo', 'crowd_sourced'));

comment on table public.crowd_position_reports is
  'Write-only inbox of individual GPS pings from consenting riders (bundled into the "Deteksi Otomatis Naik KRL" setting). Retained only briefly — refresh_crowd_vehicle_positions() aggregates and deletes rows older than its retention window on every call, so raw location pings never accumulate indefinitely (PRD §32 retention requirement).';

-- ============================================================================
-- Aggregation: fold recent per-trip reports into public.vehicle_positions,
-- and enforce the retention window by deleting old raw reports every call.
-- Mirrors refresh_estimated_vehicle_positions()'s delete-then-insert
-- pattern for its own `source` slice — never touches other sources.
-- ============================================================================

create or replace function public.refresh_crowd_vehicle_positions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  -- Retention: raw pings older than 10 minutes are deleted unconditionally,
  -- whether or not they were just aggregated below.
  delete from public.crowd_position_reports
  where reported_at < now() - interval '10 minutes';

  delete from public.vehicle_positions where source = 'crowd_sourced';

  with recent as (
    select
      external_trip_id,
      service_date,
      latitude,
      longitude,
      reported_at,
      device_session_id
    from public.crowd_position_reports
    where reported_at >= now() - interval '3 minutes'
  ),
  aggregated as (
    select
      external_trip_id,
      service_date,
      avg(latitude) as latitude,
      avg(longitude) as longitude,
      max(reported_at) as recorded_at,
      count(distinct device_session_id) as reporter_count
    from recent
    group by external_trip_id, service_date
  )
  insert into public.vehicle_positions (
    trip_id, vehicle_id, latitude, longitude, status,
    recorded_at, source, accuracy_status
  )
  select
    t.id,
    a.external_trip_id,
    a.latitude,
    a.longitude,
    'in_transit_to',
    a.recorded_at,
    'crowd_sourced',
    'near_real_time'
  from aggregated a
  left join public.trips t
    on t.external_trip_id = a.external_trip_id
    and t.service_date = a.service_date;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.refresh_crowd_vehicle_positions is
  'Deletes crowd_position_reports older than 10 minutes (retention), then folds reports from the last 3 minutes into vehicle_positions (source=crowd_sourced, accuracy_status=near_real_time), averaged per (external_trip_id, service_date). Left-joins to public.trips to resolve a real trip_id when that service_date has been imported; leaves trip_id null otherwise rather than dropping the position. Never touches other vehicle_positions sources.';

revoke all on function public.refresh_crowd_vehicle_positions() from public, anon, authenticated;
grant execute on function public.refresh_crowd_vehicle_positions() to service_role;

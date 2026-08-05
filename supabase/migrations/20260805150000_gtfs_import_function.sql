-- ============================================================================
-- Backs the Next.js admin panel's GTFS Schedule (static) import
-- (admin/lib/gtfs/importer.ts). `trips_external_service_unique_idx` (see
-- 20260804130000_initial_schema.sql) is a PARTIAL unique index — Postgres
-- will not match a plain `insert ... on conflict (line_id, external_trip_id,
-- service_date) do update` against it (confirmed by testing directly:
-- "there is no unique or exclusion constraint matching the ON CONFLICT
-- specification"), and PostgREST's upsert (what supabase-js's `.upsert()`
-- generates) has no way to add the index's `where external_trip_id is not
-- null` predicate to the conflict target. A SQL function that spells out
-- the full `on conflict (...) where ...` clause is the only way to upsert
-- against a partial unique index through PostgREST.
-- ============================================================================

create or replace function public.import_gtfs_trips(p_trips jsonb)
returns table (out_external_trip_id text, out_service_date date, out_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Output column names are prefixed (out_*) to avoid colliding with
  -- `public.trips.external_trip_id`/`service_date` — PL/pgSQL implicitly
  -- declares a variable per OUT parameter, and an unprefixed name here
  -- would shadow the table column inside the `on conflict` clause below
  -- (confirmed by testing: "column reference is ambiguous").
  insert into public.trips (
    external_trip_id, line_id, service_id, headsign, trip_number, data_source, service_date
  )
  select
    r.external_trip_id,
    r.line_id,
    r.service_id,
    r.headsign,
    r.trip_number,
    r.data_source,
    r.service_date
  from jsonb_to_recordset(p_trips) as r(
    external_trip_id text,
    line_id uuid,
    service_id text,
    headsign text,
    trip_number text,
    data_source text,
    service_date date
  )
  on conflict (line_id, external_trip_id, service_date) where external_trip_id is not null
  do update set
    service_id = excluded.service_id,
    headsign = excluded.headsign,
    trip_number = excluded.trip_number,
    data_source = excluded.data_source,
    updated_at = now();

  return query
  select t.external_trip_id, t.service_date, t.id
  from public.trips t
  join jsonb_to_recordset(p_trips) as r(
    external_trip_id text,
    line_id uuid,
    service_id text,
    headsign text,
    trip_number text,
    data_source text,
    service_date date
  ) on r.line_id = t.line_id
    and r.external_trip_id = t.external_trip_id
    and r.service_date = t.service_date;
end;
$$;

comment on function public.import_gtfs_trips is
  'Bulk upsert of GTFS-imported trip rows against the partial unique index on (line_id, external_trip_id, service_date). Called only from the admin panel via the service-role client — never exposed to anon/authenticated.';

revoke all on function public.import_gtfs_trips(jsonb) from public, anon, authenticated;
grant execute on function public.import_gtfs_trips(jsonb) to service_role;

-- ============================================================================
-- Schedule-based estimated vehicle positions.
--
-- Reimplements the "Teman Kereta Live Starter" package's straight-line
-- interpolation idea directly against THIS schema's already-populated
-- `public.trips` / `public.stop_times` / `public.stations` (concrete dated
-- trips, not a recurring GTFS calendar - see the initial schema's comment on
-- `trips.service_date`), instead of standing up a second, separate GTFS
-- database/schema the way that package's own `backend/` does.
--
-- `public.vehicle_positions` already has exactly the right shape for this
-- (`source`, `accuracy_status`) - see `20260804130000_initial_schema.sql` -
-- it was simply never populated. This function is the missing writer.
--
-- Call cadence is external (see admin/scripts/refresh-vehicle-positions.mjs)
-- since this project has no pg_cron dependency yet; each call fully replaces
-- the 'estimated' rows so stale/ended trips never linger.
--
-- Never touches rows with source <> 'estimated' - a real GTFS-Realtime feed
-- (source = 'gtfs_realtime') or demo seed rows are left alone.
-- ============================================================================

create or replace function public.refresh_estimated_vehicle_positions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  delete from public.vehicle_positions where source = 'estimated';

  with active_trips as (
    select t.id as trip_id, t.external_trip_id, t.service_date
    from public.trips t
    where t.service_date between (current_date - 1) and current_date
  ),
  bounds as (
    select
      at.trip_id,
      at.external_trip_id,
      at.service_date,
      min((at.service_date + st.scheduled_departure) at time zone s.timezone) as trip_start,
      max((at.service_date + st.scheduled_arrival) at time zone s.timezone) as trip_end
    from active_trips at
    join public.stop_times st on st.trip_id = at.trip_id
    join public.stations s on s.id = st.station_id
    group by at.trip_id, at.external_trip_id, at.service_date
  ),
  current_trips as (
    select * from bounds
    where now() between trip_start and trip_end
  ),
  prev_stop as (
    select distinct on (ct.trip_id)
      ct.trip_id,
      st.station_id,
      st.stop_sequence,
      (ct.service_date + st.scheduled_departure) at time zone s.timezone as departed_at,
      s.latitude,
      s.longitude
    from current_trips ct
    join public.stop_times st on st.trip_id = ct.trip_id
    join public.stations s on s.id = st.station_id
    where (ct.service_date + st.scheduled_departure) at time zone s.timezone <= now()
    order by ct.trip_id, st.stop_sequence desc
  ),
  next_stop as (
    select distinct on (ct.trip_id)
      ct.trip_id,
      st.station_id,
      st.stop_sequence,
      (ct.service_date + st.scheduled_arrival) at time zone s.timezone as arrives_at,
      s.latitude,
      s.longitude
    from current_trips ct
    join public.stop_times st on st.trip_id = ct.trip_id
    join public.stations s on s.id = st.station_id
    where (ct.service_date + st.scheduled_arrival) at time zone s.timezone >= now()
    order by ct.trip_id, st.stop_sequence asc
  ),
  interpolated as (
    select
      ct.trip_id,
      coalesce(ct.external_trip_id, ct.trip_id::text) as vehicle_id,
      p.station_id as current_station_id,
      n.station_id as next_station_id,
      case
        when n.arrives_at <= p.departed_at then 0::double precision
        else greatest(0::double precision, least(1::double precision,
          extract(epoch from (now() - p.departed_at)) /
          extract(epoch from (n.arrives_at - p.departed_at))
        ))
      end as fraction,
      p.latitude as prev_lat,
      p.longitude as prev_lon,
      n.latitude as next_lat,
      n.longitude as next_lon
    from current_trips ct
    join prev_stop p on p.trip_id = ct.trip_id
    join next_stop n on n.trip_id = ct.trip_id
  )
  insert into public.vehicle_positions (
    trip_id, vehicle_id, latitude, longitude,
    current_station_id, next_station_id, status,
    recorded_at, source, accuracy_status
  )
  select
    trip_id,
    vehicle_id,
    prev_lat + (next_lat - prev_lat) * fraction,
    prev_lon + (next_lon - prev_lon) * fraction,
    current_station_id,
    next_station_id,
    'in_transit_to',
    now(),
    'estimated',
    'estimated'
  from interpolated;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.refresh_estimated_vehicle_positions is
  'Replaces all source=estimated rows in vehicle_positions with a fresh straight-line interpolation (previous station -> next station) for every trip currently in its scheduled service window. Intended to be called on a short interval by an external poller (see admin/scripts/refresh-vehicle-positions.mjs); never touches gtfs_realtime/official_api/demo rows.';

-- This ingests/writes reference-adjacent realtime state, not a public read
-- API - restrict to the service-role key, same posture as the admin panel's
-- other writers (see admin/lib/supabase/service.ts).
revoke all on function public.refresh_estimated_vehicle_positions() from public, anon, authenticated;
grant execute on function public.refresh_estimated_vehicle_positions() to service_role;

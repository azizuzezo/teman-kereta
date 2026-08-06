-- ============================================================================
-- Adds external_trip_id/service_date to the trip-search functions' output,
-- so SupabaseTransitProvider can tag each TripLeg with the shared
-- (external_trip_id, service_date) identifier crowd-sourced position
-- reporting keys off (see 20260806090000_crowd_sourced_positions.sql) — the
-- one thing every provider agrees on regardless of which is active.
--
-- Return-type changes require dropping the old signatures first; nothing
-- about the existing WHERE/JOIN logic changes, just the SELECT list.
-- ============================================================================

drop function if exists public.search_direct_trips(text, text, timestamptz, integer);

create or replace function public.search_direct_trips(
  p_origin_code text,
  p_destination_code text,
  p_from timestamptz,
  p_limit integer default 5
)
returns table (
  trip_id uuid,
  external_trip_id text,
  service_date date,
  line_name text,
  line_color text,
  headsign text,
  trip_number text,
  data_source text,
  origin_sequence integer,
  destination_sequence integer,
  origin_departure timestamptz,
  destination_arrival timestamptz
)
language sql
stable
as $$
  select
    t.id as trip_id,
    t.external_trip_id,
    t.service_date,
    l.name as line_name,
    l.color as line_color,
    t.headsign,
    t.trip_number,
    t.data_source,
    o.stop_sequence as origin_sequence,
    d.stop_sequence as destination_sequence,
    (t.service_date + o.scheduled_departure) at time zone os.timezone as origin_departure,
    (t.service_date + d.scheduled_arrival) at time zone ds.timezone as destination_arrival
  from public.trips t
  join public.lines l on l.id = t.line_id
  join public.stop_times o on o.trip_id = t.id
  join public.stations os on os.id = o.station_id and os.code = p_origin_code
  join public.stop_times d on d.trip_id = t.id
  join public.stations ds on ds.id = d.station_id and ds.code = p_destination_code
  where o.stop_sequence < d.stop_sequence
    and (t.service_date + o.scheduled_departure) at time zone os.timezone >= p_from
  order by origin_departure asc
  limit greatest(1, least(p_limit, 20));
$$;

comment on function public.search_direct_trips is
  'Direct (no-transfer) trip candidates between two stations on the same trip_id. Returns nothing if the pair only connects via a transfer — there is no multi-leg router yet. Includes external_trip_id/service_date for crowd-sourced position tagging.';

grant execute on function public.search_direct_trips(text, text, timestamptz, integer) to anon, authenticated;

drop function if exists public.search_one_transfer_trips(text, text, timestamptz, integer, integer, integer);

create or replace function public.search_one_transfer_trips(
  p_origin_code text,
  p_destination_code text,
  p_from timestamptz,
  p_horizon_hours integer default 3,
  p_transfer_buffer_seconds integer default 180,
  p_limit integer default 5
)
returns table (
  outbound_trip_id uuid,
  outbound_external_trip_id text,
  outbound_service_date date,
  outbound_line_name text,
  outbound_line_color text,
  outbound_headsign text,
  outbound_trip_number text,
  outbound_data_source text,
  outbound_origin_sequence integer,
  outbound_transfer_sequence integer,
  outbound_origin_departure timestamptz,
  outbound_transfer_arrival timestamptz,
  transfer_station_code text,
  inbound_trip_id uuid,
  inbound_external_trip_id text,
  inbound_service_date date,
  inbound_line_name text,
  inbound_line_color text,
  inbound_headsign text,
  inbound_trip_number text,
  inbound_data_source text,
  inbound_transfer_sequence integer,
  inbound_destination_sequence integer,
  inbound_transfer_departure timestamptz,
  inbound_destination_arrival timestamptz
)
language sql
stable
as $$
  with outbound as (
    select
      t.id as trip_id,
      t.external_trip_id,
      t.service_date,
      l.name as line_name,
      l.color as line_color,
      t.headsign,
      t.trip_number,
      t.data_source,
      o.stop_sequence as origin_sequence,
      tr.stop_sequence as transfer_sequence,
      tr.station_id as transfer_station_id,
      ts.code as transfer_station_code,
      (t.service_date + o.scheduled_departure) at time zone os.timezone as origin_departure,
      (t.service_date + tr.scheduled_arrival) at time zone ts.timezone as transfer_arrival
    from public.trips t
    join public.lines l on l.id = t.line_id
    join public.stop_times o on o.trip_id = t.id
    join public.stations os on os.id = o.station_id and os.code = p_origin_code
    join public.stop_times tr
      on tr.trip_id = t.id and tr.stop_sequence > o.stop_sequence
    join public.stations ts
      on ts.id = tr.station_id
      and ts.code <> p_origin_code
      and ts.code <> p_destination_code
    where (t.service_date + o.scheduled_departure) at time zone os.timezone >= p_from
      and (t.service_date + o.scheduled_departure) at time zone os.timezone
        < p_from + make_interval(hours => p_horizon_hours)
  ),
  inbound as (
    select
      t.id as trip_id,
      t.external_trip_id,
      t.service_date,
      l.name as line_name,
      l.color as line_color,
      t.headsign,
      t.trip_number,
      t.data_source,
      tr.stop_sequence as transfer_sequence,
      d.stop_sequence as destination_sequence,
      tr.station_id as transfer_station_id,
      (t.service_date + tr.scheduled_departure) at time zone ts.timezone as transfer_departure,
      (t.service_date + d.scheduled_arrival) at time zone ds.timezone as destination_arrival
    from public.trips t
    join public.lines l on l.id = t.line_id
    join public.stop_times d on d.trip_id = t.id
    join public.stations ds on ds.id = d.station_id and ds.code = p_destination_code
    join public.stop_times tr
      on tr.trip_id = t.id and tr.stop_sequence < d.stop_sequence
    join public.stations ts on ts.id = tr.station_id
    where (t.service_date + d.scheduled_arrival) at time zone ds.timezone >= p_from
      and (t.service_date + d.scheduled_arrival) at time zone ds.timezone
        < p_from + make_interval(hours => p_horizon_hours) + interval '2 hours'
  )
  select
    ob.trip_id,
    ob.external_trip_id,
    ob.service_date,
    ob.line_name,
    ob.line_color,
    ob.headsign,
    ob.trip_number,
    ob.data_source,
    ob.origin_sequence,
    ob.transfer_sequence,
    ob.origin_departure,
    ob.transfer_arrival,
    ob.transfer_station_code,
    ib.trip_id,
    ib.external_trip_id,
    ib.service_date,
    ib.line_name,
    ib.line_color,
    ib.headsign,
    ib.trip_number,
    ib.data_source,
    ib.transfer_sequence,
    ib.destination_sequence,
    ib.transfer_departure,
    ib.destination_arrival
  from outbound ob
  join inbound ib
    on ib.transfer_station_id = ob.transfer_station_id
    and ib.trip_id <> ob.trip_id
    and ib.transfer_departure >= ob.transfer_arrival + make_interval(secs => p_transfer_buffer_seconds)
  order by ob.origin_departure asc, (ib.destination_arrival - ob.origin_departure) asc
  limit greatest(1, least(p_limit, 20));
$$;

comment on function public.search_one_transfer_trips is
  'Trip candidates between two stations requiring exactly one line change, found by joining a direct-from-origin leg to a direct-to-destination leg at a shared transfer station, respecting p_transfer_buffer_seconds as the minimum dwell. Not a general router - see the file header comment. Includes external_trip_id/service_date per leg for crowd-sourced position tagging.';

grant execute on function public.search_one_transfer_trips(text, text, timestamptz, integer, integer, integer)
  to anon, authenticated;

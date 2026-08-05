-- ============================================================================
-- Query helpers backing the Flutter `local_supabase` transit provider.
--
-- The base schema stores `stop_times.scheduled_*` as `interval` plus
-- `trips.service_date` (see docs/backend-local.md's "Catatan waktu GTFS") so
-- that GTFS times past midnight (25:10:00) don't lose their service date.
-- These functions do the `service_date + interval -> timestamptz` conversion
-- server-side, in the station's own timezone, so PostgREST callers never have
-- to reimplement that conversion client-side.
--
-- Scope note: `search_direct_trips` only finds trips that serve both stations
-- on the SAME trip_id (no transfers). A general multi-transfer router is not
-- implemented — see ENGINEERING.md's "Known gaps".
-- ============================================================================

create or replace function public.get_station_departures(
  p_station_code text,
  p_from timestamptz,
  p_limit integer default 20
)
returns table (
  trip_id uuid,
  external_trip_id text,
  headsign text,
  trip_number text,
  line_name text,
  line_color text,
  data_source text,
  scheduled_departure timestamptz
)
language sql
stable
as $$
  select
    t.id as trip_id,
    t.external_trip_id,
    t.headsign,
    t.trip_number,
    l.name as line_name,
    l.color as line_color,
    t.data_source,
    (t.service_date + st.scheduled_departure) at time zone s.timezone as scheduled_departure
  from public.stop_times st
  join public.stations s on s.id = st.station_id
  join public.trips t on t.id = st.trip_id
  join public.lines l on l.id = t.line_id
  where s.code = p_station_code
    and s.is_active
    and t.data_source is not null
    and (t.service_date + st.scheduled_departure) at time zone s.timezone >= p_from
  order by scheduled_departure asc
  limit greatest(1, least(p_limit, 100));
$$;

comment on function public.get_station_departures is
  'Upcoming departures from a station (by its short code), with the GTFS-style interval + service_date pair already resolved to a real timestamptz.';

create or replace function public.search_direct_trips(
  p_origin_code text,
  p_destination_code text,
  p_from timestamptz,
  p_limit integer default 5
)
returns table (
  trip_id uuid,
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
  'Direct (no-transfer) trip candidates between two stations on the same trip_id. Returns nothing if the pair only connects via a transfer — there is no multi-leg router yet.';

create or replace function public.get_trip_stop_codes(
  p_trip_id uuid,
  p_from_sequence integer,
  p_to_sequence integer
)
returns table (station_code text, stop_sequence integer)
language sql
stable
as $$
  select s.code, st.stop_sequence
  from public.stop_times st
  join public.stations s on s.id = st.station_id
  where st.trip_id = p_trip_id
    and st.stop_sequence between p_from_sequence and p_to_sequence
  order by st.stop_sequence asc;
$$;

comment on function public.get_trip_stop_codes is
  'Ordered station codes for a slice of one trip — used to build a TripLeg.stationIds list for a matched direct trip.';

grant execute on function public.get_station_departures(text, timestamptz, integer) to anon, authenticated;
grant execute on function public.search_direct_trips(text, text, timestamptz, integer) to anon, authenticated;
grant execute on function public.get_trip_stop_codes(uuid, integer, integer) to anon, authenticated;

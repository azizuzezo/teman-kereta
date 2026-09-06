-- ============================================================================
-- Stasiun Karet (code KAT, Cikarang Loop line) permanently closed 2026-09-01.
--
-- Deactivating the row alone is not enough: `search_direct_trips`,
-- `search_one_transfer_trips`, and `get_trip_stop_codes`
-- (20260805090000_transit_query_functions.sql, 20260805180000_one_transfer_trips.sql)
-- never filtered `stations.is_active` on any of the stations they join
-- against (only `get_station_departures` did). A closed station could still
-- be returned as an origin/destination, an intermediate stop, or even a
-- one-transfer `transfer_station_code`. This migration closes that gap for
-- every station, not just Karet, so any future closure only needs the single
-- `is_active` flip below.
-- ============================================================================

-- CATATAN (6 September 2026): versi pertama migrasi ini disalin dari definisi
-- 20260805090000 dan tanpa sengaja membuang kolom yang ditambahkan
-- 20260806093000_trip_search_external_ids.sql — external_trip_id/service_date
-- pada search_direct_trips, dan keempat padanannya pada
-- search_one_transfer_trips. Postgres menolaknya ("cannot change return type of
-- existing function"), yang untungnya menahan regresi: keenam kolom itu dibaca
-- SupabaseTransitProvider (lib/data/providers/supabase_transit_provider.dart)
-- untuk melaporkan posisi kereta dari GPS penumpang. Kolomnya sudah
-- dikembalikan di bawah; jangan dihapus lagi saat menyunting fungsi-fungsi ini.

update public.stations set is_active = false where code = 'KAT';

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
  join public.stations os on os.id = o.station_id and os.code = p_origin_code and os.is_active
  join public.stop_times d on d.trip_id = t.id
  join public.stations ds on ds.id = d.station_id and ds.code = p_destination_code and ds.is_active
  where o.stop_sequence < d.stop_sequence
    and (t.service_date + o.scheduled_departure) at time zone os.timezone >= p_from
    and not exists (
      select 1
      from public.stop_times mid
      join public.stations ms on ms.id = mid.station_id
      where mid.trip_id = t.id
        and mid.stop_sequence between o.stop_sequence and d.stop_sequence
        and not ms.is_active
    )
  order by origin_departure asc
  limit greatest(1, least(p_limit, 20));
$$;

comment on function public.search_direct_trips is
  'Direct (no-transfer) trip candidates between two stations on the same trip_id. Returns nothing if the pair only connects via a transfer, or if every candidate trip would pass through a closed (is_active = false) station along the way.';

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
    and s.is_active
  order by st.stop_sequence asc;
$$;

comment on function public.get_trip_stop_codes is
  'Ordered station codes for a slice of one trip — used to build a TripLeg.stationIds list for a matched direct trip. Closed stations (is_active = false) are skipped rather than listed as a stop.';

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
    join public.stations os on os.id = o.station_id and os.code = p_origin_code and os.is_active
    join public.stop_times tr
      on tr.trip_id = t.id and tr.stop_sequence > o.stop_sequence
    join public.stations ts
      on ts.id = tr.station_id
      and ts.code <> p_origin_code
      and ts.code <> p_destination_code
      and ts.is_active
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
    join public.stations ds on ds.id = d.station_id and ds.code = p_destination_code and ds.is_active
    join public.stop_times tr
      on tr.trip_id = t.id and tr.stop_sequence < d.stop_sequence
    join public.stations ts on ts.id = tr.station_id and ts.is_active
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
  'Trip candidates between two stations requiring exactly one line change, found by joining a direct-from-origin leg to a direct-to-destination leg at a shared transfer station, respecting p_transfer_buffer_seconds as the minimum dwell. Closed stations (is_active = false) are never used as origin, destination, transfer point, or intermediate stop. Not a general router - see the file header comment on search_direct_trips.';

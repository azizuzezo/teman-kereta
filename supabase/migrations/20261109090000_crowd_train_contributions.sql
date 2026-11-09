-- ============================================================================
-- Riders' GPS as a contribution: running trains and timetable accuracy.
--
-- Same consent as the existing crowd positions (the "Deteksi Otomatis Naik
-- KRL" setting), same posture: insert-only inboxes, short retention, only
-- aggregates are ever readable.
--
-- 1. Trains on the map without a timetable id. The imported KRL timetable is
--    for a past week, so most trips the app plans are estimates with no
--    `external_trip_id`; those riders never reported a position at all. The
--    app now reports them under a segment key, `seg:<from>><to>` (station
--    codes of the hop the train is on). refresh_crowd_vehicle_positions()
--    learns that key: it fills current/next station, and uses only each
--    device's latest ping so a moving train is not smeared along the hop.
--
-- 2. Timetable accuracy. When a rider's phone (GPS, never a manual tap)
--    reaches the next station, the app reports "passed station X towards Y
--    at T". A trigger matches that against the official timetable for the
--    same weekday (the latest scheduled stop at X towards Y at or before T,
--    within 30 minutes) and stores the delay. get_crowd_delays(station)
--    returns the median delay per direction over the last 45 minutes, with
--    how many distinct phones reported it — never the raw rows.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 2a. Station passages inbox
-- ---------------------------------------------------------------------------

create table public.crowd_station_passages (
  id uuid primary key default gen_random_uuid(),
  station_code text not null check (char_length(station_code) between 1 and 20),
  -- Direction of travel: the next stop, or (at the last stop) the previous.
  next_station_code text check (char_length(next_station_code) between 1 and 20),
  prev_station_code text check (char_length(prev_station_code) between 1 and 20),
  passed_at timestamptz not null,
  -- Filled by the trigger below, never by the client.
  scheduled_at timestamptz,
  delay_seconds integer,
  device_session_id text not null check (char_length(device_session_id) between 1 and 100),
  created_at timestamptz not null default now(),
  check (passed_at between now() - interval '15 minutes' and now() + interval '2 minutes'),
  check (next_station_code is not null or prev_station_code is not null)
);

create index crowd_station_passages_station_idx
  on public.crowd_station_passages (station_code, passed_at desc);

alter table public.crowd_station_passages enable row level security;

create or replace function public.crowd_passage_rate_ok(p_device_session_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.crowd_station_passages
    where device_session_id = p_device_session_id
      and created_at > now() - interval '30 seconds'
  )
$$;

revoke all on function public.crowd_passage_rate_ok(text) from public;
grant execute on function public.crowd_passage_rate_ok(text) to anon, authenticated;

create policy "Anyone can report passing a station"
  on public.crowd_station_passages
  for insert
  to anon, authenticated
  with check (
    public.crowd_passage_rate_ok(device_session_id)
    and scheduled_at is null
    and delay_seconds is null
  );

revoke all on table public.crowd_station_passages from public;
grant insert on table public.crowd_station_passages to anon, authenticated;
grant all on table public.crowd_station_passages to service_role;

-- Matches a passage to the official timetable. Runs as the table owner so it
-- can read stop_times regardless of the inserting role.
create or replace function public.crowd_passage_match_schedule()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_local timestamp := new.passed_at at time zone 'Asia/Jakarta';
  v_tod interval := v_local::time::interval;
  v_isodow numeric := extract(isodow from v_local::date);
  v_scheduled interval;
begin
  -- Never trust client-supplied results.
  new.scheduled_at := null;
  new.delay_seconds := null;

  -- The imported timetable covers past dates: match the same weekday.
  if new.next_station_code is not null then
    select max(mod_tod) into v_scheduled
    from (
      select make_interval(
               secs => mod(extract(epoch from st.scheduled_arrival)::int, 86400)
             ) as mod_tod
      from public.stop_times st
      join public.trips t on t.id = st.trip_id
        and extract(isodow from t.service_date) = v_isodow
      join public.stations s on s.id = st.station_id and s.code = new.station_code
      join public.stop_times nx
        on nx.trip_id = st.trip_id and nx.stop_sequence = st.stop_sequence + 1
      join public.stations ns on ns.id = nx.station_id and ns.code = new.next_station_code
    ) candidates
    where mod_tod <= v_tod + interval '1 minute'
      and mod_tod >= v_tod - interval '30 minutes';
  else
    select max(mod_tod) into v_scheduled
    from (
      select make_interval(
               secs => mod(extract(epoch from st.scheduled_arrival)::int, 86400)
             ) as mod_tod
      from public.stop_times st
      join public.trips t on t.id = st.trip_id
        and extract(isodow from t.service_date) = v_isodow
      join public.stations s on s.id = st.station_id and s.code = new.station_code
      join public.stop_times pv
        on pv.trip_id = st.trip_id and pv.stop_sequence = st.stop_sequence - 1
      join public.stations ps on ps.id = pv.station_id and ps.code = new.prev_station_code
    ) candidates
    where mod_tod <= v_tod + interval '1 minute'
      and mod_tod >= v_tod - interval '30 minutes';
  end if;

  if v_scheduled is not null then
    new.scheduled_at := (v_local::date + v_scheduled) at time zone 'Asia/Jakarta';
    new.delay_seconds := greatest(
      extract(epoch from (new.passed_at - new.scheduled_at))::int,
      -60
    );
  end if;
  return new;
end;
$$;

create trigger crowd_station_passages_match_schedule
  before insert on public.crowd_station_passages
  for each row execute function public.crowd_passage_match_schedule();

-- Median delay per direction at one station, last 45 minutes. Directions are
-- named by the next station (or "from" the previous one at a terminus).
create or replace function public.get_crowd_delays(p_station_code text)
returns table (
  toward_station_code text,
  toward_station_name text,
  median_delay_seconds integer,
  reporters integer,
  last_passed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    coalesce(p.next_station_code, p.prev_station_code) as toward_station_code,
    s.name as toward_station_name,
    percentile_cont(0.5) within group (order by p.delay_seconds)::int
      as median_delay_seconds,
    count(distinct p.device_session_id)::int as reporters,
    max(p.passed_at) as last_passed_at
  from public.crowd_station_passages p
  left join public.stations s
    on s.code = coalesce(p.next_station_code, p.prev_station_code)
  where p.station_code = p_station_code
    and p.delay_seconds is not null
    and p.passed_at > now() - interval '45 minutes'
  group by 1, 2
  order by max(p.passed_at) desc
$$;

revoke all on function public.get_crowd_delays(text) from public;
grant execute on function public.get_crowd_delays(text) to anon, authenticated;

-- Network-wide summary for the home screen: how many phones contributed in
-- the last 30 minutes, and the median delay across all of them.
create or replace function public.get_crowd_network_status()
returns table (
  reporters integer,
  passages integer,
  median_delay_seconds integer,
  trains_on_map integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select count(distinct device_session_id)::int
       from public.crowd_station_passages
       where passed_at > now() - interval '30 minutes'),
    (select count(*)::int
       from public.crowd_station_passages
       where passed_at > now() - interval '30 minutes'
         and delay_seconds is not null),
    (select percentile_cont(0.5) within group (order by delay_seconds)::int
       from public.crowd_station_passages
       where passed_at > now() - interval '30 minutes'
         and delay_seconds is not null),
    (select count(*)::int
       from public.vehicle_positions
       where source = 'crowd_sourced'
         and recorded_at > now() - interval '5 minutes')
$$;

revoke all on function public.get_crowd_network_status() from public;
grant execute on function public.get_crowd_network_status() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1. Crowd positions: segment keys, latest ping per phone, retention
-- ---------------------------------------------------------------------------

-- What the train is, as the rider's app knows it: where it is heading
-- (terminus) and the service it runs. Shown on the map instead of anything
-- about the rider.
alter table public.crowd_position_reports
  add column headsign text check (char_length(headsign) between 1 and 80),
  add column relation text check (char_length(relation) between 1 and 80);

alter table public.vehicle_positions
  add column if not exists headsign text,
  add column if not exists relation text;

create or replace function public.refresh_crowd_vehicle_positions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  -- Retention: raw pings older than 10 minutes, passages older than 3 hours.
  delete from public.crowd_position_reports
  where reported_at < now() - interval '10 minutes';
  delete from public.crowd_station_passages
  where passed_at < now() - interval '3 hours';

  delete from public.vehicle_positions where source = 'crowd_sourced';

  with latest as (
    -- Each phone's newest ping per train in the last 2 minutes.
    select distinct on (external_trip_id, service_date, device_session_id)
      external_trip_id, service_date, latitude, longitude, reported_at,
      device_session_id, headsign, relation
    from public.crowd_position_reports
    where reported_at >= now() - interval '2 minutes'
    order by external_trip_id, service_date, device_session_id, reported_at desc
  ),
  aggregated as (
    select
      external_trip_id,
      service_date,
      avg(latitude) as latitude,
      avg(longitude) as longitude,
      max(reported_at) as recorded_at,
      mode() within group (order by headsign) as headsign,
      mode() within group (order by relation) as relation
    from latest
    group by external_trip_id, service_date
  ),
  keyed as (
    select
      a.*,
      case when a.external_trip_id like 'seg:%>%'
        then split_part(substr(a.external_trip_id, 5), '>', 1) end as from_code,
      case when a.external_trip_id like 'seg:%>%'
        then split_part(substr(a.external_trip_id, 5), '>', 2) end as to_code
    from aggregated a
  )
  insert into public.vehicle_positions (
    trip_id, vehicle_id, latitude, longitude,
    current_station_id, next_station_id, status,
    recorded_at, source, accuracy_status, headsign, relation
  )
  select
    t.id,
    k.external_trip_id,
    k.latitude,
    k.longitude,
    fs.id,
    ts.id,
    'in_transit_to',
    k.recorded_at,
    'crowd_sourced',
    'near_real_time',
    coalesce(k.headsign, t.headsign),
    k.relation
  from keyed k
  left join public.trips t
    on t.external_trip_id = k.external_trip_id
    and t.service_date = k.service_date
  left join public.stations fs on fs.code = k.from_code
  left join public.stations ts on ts.code = k.to_code;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.refresh_crowd_vehicle_positions() from public, anon, authenticated;
grant execute on function public.refresh_crowd_vehicle_positions() to service_role;

begin;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Identity and user-owned data
-- ---------------------------------------------------------------------------

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (display_name is null or char_length(display_name) between 1 and 80),
  email text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index users_email_lower_unique_idx
  on public.users (lower(email))
  where email is not null;

create table public.user_preferences (
  user_id uuid primary key references public.users (id) on delete cascade,
  language text not null default 'id' check (language in ('id', 'en')),
  theme text not null default 'system' check (theme in ('system', 'light', 'dark')),
  reduce_motion boolean not null default false,
  notification_enabled boolean not null default true,
  vibration_enabled boolean not null default true,
  sound_enabled boolean not null default true,
  destination_alert_stops smallint not null default 3
    check (destination_alert_stops between 1 and 5),
  location_mode text not null default 'while_using'
    check (location_mode in ('off', 'while_using', 'during_trip')),
  analytics_consent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Provider-neutral transit reference and schedule data
-- ---------------------------------------------------------------------------

create table public.operators (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 160),
  operator_type text not null
    check (operator_type in ('rail', 'metro', 'lrt', 'bus', 'minibus', 'ferry', 'other')),
  logo_url text,
  website text,
  data_source_type text not null
    check (data_source_type in ('official_api', 'gtfs', 'gtfs_realtime', 'open_data', 'curated', 'demo')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.lines (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.operators (id) on delete restrict,
  code text not null check (char_length(code) between 1 and 40),
  name text not null check (char_length(name) between 1 and 160),
  color text check (color is null or color ~ '^#[0-9A-Fa-f]{6}$'),
  text_color text check (text_color is null or text_color ~ '^#[0-9A-Fa-f]{6}$'),
  transport_mode text not null
    check (transport_mode in ('rail', 'metro', 'lrt', 'brt', 'bus', 'minibus', 'walk', 'bicycle', 'other')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (operator_id, code)
);

create table public.stations (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (char_length(code) between 1 and 40),
  name text not null check (char_length(name) between 1 and 160),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  address text,
  timezone text not null default 'Asia/Jakarta',
  wheelchair_accessible boolean,
  facilities jsonb not null default '{}'::jsonb
    check (jsonb_typeof(facilities) = 'object'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.station_lines (
  station_id uuid not null references public.stations (id) on delete cascade,
  line_id uuid not null references public.lines (id) on delete cascade,
  stop_order integer check (stop_order is null or stop_order > 0),
  platform_information jsonb not null default '{}'::jsonb
    check (jsonb_typeof(platform_information) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (station_id, line_id)
);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  external_trip_id text,
  line_id uuid not null references public.lines (id) on delete restrict,
  service_id text not null check (char_length(service_id) between 1 and 100),
  headsign text not null check (char_length(headsign) between 1 and 160),
  direction_id smallint check (direction_id in (0, 1)),
  trip_number text,
  data_source text not null
    check (data_source in ('official_api', 'gtfs', 'gtfs_realtime', 'curated', 'demo')),
  service_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index trips_external_service_unique_idx
  on public.trips (line_id, external_trip_id, service_date)
  where external_trip_id is not null;

create table public.stop_times (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  station_id uuid not null references public.stations (id) on delete restrict,
  stop_sequence integer not null check (stop_sequence > 0),
  -- GTFS permits times after 24:00; intervals retain that information correctly.
  scheduled_arrival interval not null
    check (scheduled_arrival >= interval '0 seconds' and scheduled_arrival < interval '48 hours'),
  scheduled_departure interval not null
    check (scheduled_departure >= scheduled_arrival and scheduled_departure < interval '48 hours'),
  pickup_type smallint not null default 0 check (pickup_type between 0 and 3),
  drop_off_type smallint not null default 0 check (drop_off_type between 0 and 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (trip_id, stop_sequence)
);

-- ---------------------------------------------------------------------------
-- Realtime transit state and disruptions
-- ---------------------------------------------------------------------------

create table public.vehicle_positions (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references public.trips (id) on delete cascade,
  vehicle_id text not null check (char_length(vehicle_id) between 1 and 120),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  bearing real check (bearing >= 0 and bearing < 360),
  speed real check (speed >= 0),
  current_station_id uuid references public.stations (id) on delete set null,
  next_station_id uuid references public.stations (id) on delete set null,
  status text not null default 'unknown'
    check (status in ('incoming_at', 'stopped_at', 'in_transit_to', 'unknown')),
  recorded_at timestamptz not null,
  source text not null
    check (source in ('official_api', 'gtfs_realtime', 'estimated', 'demo')),
  accuracy_status text not null
    check (accuracy_status in ('real_time', 'near_real_time', 'estimated', 'unavailable')),
  created_at timestamptz not null default now()
);

create table public.trip_updates (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  station_id uuid not null references public.stations (id) on delete cascade,
  arrival_delay_seconds integer,
  departure_delay_seconds integer,
  predicted_arrival timestamptz,
  predicted_departure timestamptz,
  updated_at timestamptz not null default now(),
  unique (trip_id, station_id)
);

create table public.service_alerts (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid references public.operators (id) on delete set null,
  line_id uuid references public.lines (id) on delete set null,
  station_id uuid references public.stations (id) on delete set null,
  title text not null check (char_length(title) between 1 and 180),
  description text not null check (char_length(description) between 1 and 4000),
  severity text not null check (severity in ('info', 'warning', 'severe', 'critical')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  source text not null,
  is_official boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table public.transfer_rules (
  id uuid primary key default gen_random_uuid(),
  from_station_id uuid not null references public.stations (id) on delete cascade,
  to_station_id uuid not null references public.stations (id) on delete cascade,
  minimum_transfer_seconds integer not null default 0 check (minimum_transfer_seconds >= 0),
  walking_distance integer check (walking_distance is null or walking_distance >= 0),
  accessibility_notes text,
  instructions text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (from_station_id, to_station_id)
);

create table public.nearby_places (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.stations (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 180),
  category text not null check (char_length(category) between 1 and 80),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  distance_meters integer check (distance_meters is null or distance_meters >= 0),
  walking_duration_minutes integer
    check (walking_duration_minutes is null or walking_duration_minutes >= 0),
  address text,
  description text,
  image_url text,
  source text not null,
  source_external_id text,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index nearby_places_source_external_unique_idx
  on public.nearby_places (station_id, source, source_external_id)
  where source_external_id is not null;

-- ---------------------------------------------------------------------------
-- Synced personal data, active trips, notifications, and reports
-- ---------------------------------------------------------------------------

create table public.user_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  favorite_type text not null check (favorite_type in ('station', 'route', 'place')),
  station_id uuid references public.stations (id) on delete restrict,
  origin_station_id uuid references public.stations (id) on delete restrict,
  destination_station_id uuid references public.stations (id) on delete restrict,
  place_id uuid references public.nearby_places (id) on delete restrict,
  label text check (label is null or char_length(label) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (favorite_type = 'station' and station_id is not null and origin_station_id is null
      and destination_station_id is null and place_id is null)
    or
    (favorite_type = 'route' and station_id is null and origin_station_id is not null
      and destination_station_id is not null and origin_station_id <> destination_station_id
      and place_id is null)
    or
    (favorite_type = 'place' and station_id is null and origin_station_id is null
      and destination_station_id is null and place_id is not null)
  )
);

create unique index user_favorites_station_unique_idx
  on public.user_favorites (user_id, station_id)
  where favorite_type = 'station';
create unique index user_favorites_route_unique_idx
  on public.user_favorites (user_id, origin_station_id, destination_station_id)
  where favorite_type = 'route';
create unique index user_favorites_place_unique_idx
  on public.user_favorites (user_id, place_id)
  where favorite_type = 'place';

create table public.commute_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  origin_station_id uuid not null references public.stations (id) on delete restrict,
  destination_station_id uuid not null references public.stations (id) on delete restrict,
  active_days smallint[] not null default array[1, 2, 3, 4, 5]::smallint[],
  departure_time time without time zone not null,
  return_time time without time zone,
  notify_before_minutes integer not null default 30 check (notify_before_minutes between 0 and 1440),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (origin_station_id <> destination_station_id),
  check (
    cardinality(active_days) between 1 and 7
    and active_days <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
  )
);

create table public.trip_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  planned_trip_id uuid references public.trips (id) on delete set null,
  matched_trip_id uuid references public.trips (id) on delete set null,
  origin_station_id uuid not null references public.stations (id) on delete restrict,
  destination_station_id uuid not null references public.stations (id) on delete restrict,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  detection_method text not null
    check (detection_method in ('manual', 'automatic', 'geofence', 'schedule_match', 'realtime_match', 'restored')),
  confidence_score smallint not null default 100 check (confidence_score between 0 and 100),
  status text not null default 'idle'
    check (status in (
      'idle', 'near_station', 'at_station', 'possible_boarding', 'confirming_trip',
      'on_board', 'approaching_transfer', 'transferring', 'approaching_destination',
      'arrived', 'missed_destination', 'completed', 'cancelled'
    )),
  location_upload_consent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (origin_station_id <> destination_station_id),
  check (ended_at is null or ended_at >= started_at)
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  device_id text not null check (char_length(device_id) between 1 and 200),
  fcm_token text not null check (char_length(fcm_token) between 20 and 4096),
  platform text not null check (platform in ('android', 'ios', 'web')),
  last_active_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_id),
  unique (fcm_token)
);

create table public.notification_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  trip_session_id uuid references public.trip_sessions (id) on delete set null,
  notification_type text not null check (char_length(notification_type) between 1 and 80),
  station_id uuid references public.stations (id) on delete set null,
  sent_at timestamptz not null default now(),
  opened_at timestamptz,
  check (opened_at is null or opened_at >= sent_at)
);

create table public.user_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  report_type text not null
    check (report_type in (
      'crowding', 'air_conditioning', 'station_facility', 'lift', 'escalator',
      'platform_change', 'delay', 'lost_item', 'emergency', 'incorrect_information', 'other'
    )),
  line_id uuid references public.lines (id) on delete set null,
  station_id uuid references public.stations (id) on delete set null,
  trip_id uuid references public.trips (id) on delete set null,
  description text not null check (char_length(description) between 1 and 2000),
  media_url text,
  latitude double precision check (latitude is null or latitude between -90 and 90),
  longitude double precision check (longitude is null or longitude between -180 and 180),
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'rejected', 'resolved', 'expired')),
  expires_at timestamptz not null default (now() + interval '6 hours'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null) = (longitude is null)),
  check (expires_at > created_at)
);

-- ---------------------------------------------------------------------------
-- Query indexes
-- ---------------------------------------------------------------------------

create index lines_operator_active_idx on public.lines (operator_id, is_active);
create index lines_name_search_idx on public.lines using gin (name extensions.gin_trgm_ops);
create index stations_name_search_idx on public.stations using gin (name extensions.gin_trgm_ops);
create index stations_active_coordinates_idx on public.stations (is_active, latitude, longitude);
create index station_lines_line_order_idx on public.station_lines (line_id, stop_order);
create index trips_line_service_date_idx on public.trips (line_id, service_date);
create index stop_times_station_departure_idx
  on public.stop_times (station_id, scheduled_departure);
create index vehicle_positions_trip_recorded_idx
  on public.vehicle_positions (trip_id, recorded_at desc);
create index vehicle_positions_vehicle_recorded_idx
  on public.vehicle_positions (vehicle_id, recorded_at desc);
create index trip_updates_station_updated_idx
  on public.trip_updates (station_id, updated_at desc);
create index service_alerts_operator_time_idx
  on public.service_alerts (operator_id, starts_at, ends_at);
create index service_alerts_line_time_idx
  on public.service_alerts (line_id, starts_at, ends_at);
create index service_alerts_station_time_idx
  on public.service_alerts (station_id, starts_at, ends_at);
create index transfer_rules_from_station_idx on public.transfer_rules (from_station_id);
create index nearby_places_station_distance_idx
  on public.nearby_places (station_id, distance_meters);
create index nearby_places_name_search_idx
  on public.nearby_places using gin (name extensions.gin_trgm_ops);
create index user_favorites_user_idx on public.user_favorites (user_id, created_at desc);
create index commute_plans_user_active_idx on public.commute_plans (user_id, is_active);
create index trip_sessions_user_started_idx on public.trip_sessions (user_id, started_at desc);
create index trip_sessions_active_idx
  on public.trip_sessions (user_id, updated_at desc)
  where status not in ('completed', 'cancelled');
create index device_tokens_user_active_idx on public.device_tokens (user_id, last_active_at desc);
create index notification_logs_user_sent_idx
  on public.notification_logs (user_id, sent_at desc);
create index notification_logs_unopened_idx
  on public.notification_logs (user_id, sent_at desc)
  where opened_at is null;
create index user_reports_user_created_idx on public.user_reports (user_id, created_at desc);
create index user_reports_moderation_idx on public.user_reports (status, expires_at);
create index user_reports_line_created_idx on public.user_reports (line_id, created_at desc);
create index user_reports_station_created_idx on public.user_reports (station_id, created_at desc);

-- ---------------------------------------------------------------------------
-- updated_at and auth profile synchronization
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger users_set_updated_at before update on public.users
  for each row execute function public.set_updated_at();
create trigger user_preferences_set_updated_at before update on public.user_preferences
  for each row execute function public.set_updated_at();
create trigger operators_set_updated_at before update on public.operators
  for each row execute function public.set_updated_at();
create trigger lines_set_updated_at before update on public.lines
  for each row execute function public.set_updated_at();
create trigger stations_set_updated_at before update on public.stations
  for each row execute function public.set_updated_at();
create trigger station_lines_set_updated_at before update on public.station_lines
  for each row execute function public.set_updated_at();
create trigger trips_set_updated_at before update on public.trips
  for each row execute function public.set_updated_at();
create trigger stop_times_set_updated_at before update on public.stop_times
  for each row execute function public.set_updated_at();
create trigger trip_updates_set_updated_at before update on public.trip_updates
  for each row execute function public.set_updated_at();
create trigger service_alerts_set_updated_at before update on public.service_alerts
  for each row execute function public.set_updated_at();
create trigger transfer_rules_set_updated_at before update on public.transfer_rules
  for each row execute function public.set_updated_at();
create trigger nearby_places_set_updated_at before update on public.nearby_places
  for each row execute function public.set_updated_at();
create trigger user_favorites_set_updated_at before update on public.user_favorites
  for each row execute function public.set_updated_at();
create trigger commute_plans_set_updated_at before update on public.commute_plans
  for each row execute function public.set_updated_at();
create trigger trip_sessions_set_updated_at before update on public.trip_sessions
  for each row execute function public.set_updated_at();
create trigger device_tokens_set_updated_at before update on public.device_tokens
  for each row execute function public.set_updated_at();
create trigger user_reports_set_updated_at before update on public.user_reports
  for each row execute function public.set_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, display_name, email, avatar_url)
  values (
    new.id,
    nullif(coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'full_name'), ''),
    new.email,
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;

  insert into public.user_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

create or replace function public.sync_auth_user_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.users
  set email = new.email
  where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.sync_auth_user_email();

-- Backfill is harmless on a fresh local database and supports pre-existing local auth rows.
insert into public.users (id, display_name, email, avatar_url, created_at, updated_at)
select
  id,
  nullif(coalesce(raw_user_meta_data ->> 'display_name', raw_user_meta_data ->> 'full_name'), ''),
  email,
  nullif(raw_user_meta_data ->> 'avatar_url', ''),
  created_at,
  coalesce(updated_at, created_at)
from auth.users
on conflict (id) do nothing;

insert into public.user_preferences (user_id)
select id from public.users
on conflict (user_id) do nothing;

revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.handle_new_auth_user() from public, anon, authenticated;
revoke all on function public.sync_auth_user_email() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security and explicit API grants
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;
alter table public.user_preferences enable row level security;
alter table public.operators enable row level security;
alter table public.lines enable row level security;
alter table public.stations enable row level security;
alter table public.station_lines enable row level security;
alter table public.trips enable row level security;
alter table public.stop_times enable row level security;
alter table public.vehicle_positions enable row level security;
alter table public.trip_updates enable row level security;
alter table public.service_alerts enable row level security;
alter table public.transfer_rules enable row level security;
alter table public.nearby_places enable row level security;
alter table public.user_favorites enable row level security;
alter table public.commute_plans enable row level security;
alter table public.trip_sessions enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notification_logs enable row level security;
alter table public.user_reports enable row level security;

-- Unauthenticated clients may only read public transit and curated place data.
create policy "Public can read operators" on public.operators
  for select to anon, authenticated using (true);
create policy "Public can read lines" on public.lines
  for select to anon, authenticated using (true);
create policy "Public can read stations" on public.stations
  for select to anon, authenticated using (true);
create policy "Public can read station lines" on public.station_lines
  for select to anon, authenticated using (true);
create policy "Public can read trips" on public.trips
  for select to anon, authenticated using (true);
create policy "Public can read stop times" on public.stop_times
  for select to anon, authenticated using (true);
create policy "Public can read vehicle positions" on public.vehicle_positions
  for select to anon, authenticated using (true);
create policy "Public can read trip updates" on public.trip_updates
  for select to anon, authenticated using (true);
create policy "Public can read service alerts" on public.service_alerts
  for select to anon, authenticated using (true);
create policy "Public can read transfer rules" on public.transfer_rules
  for select to anon, authenticated using (true);
create policy "Public can read nearby places" on public.nearby_places
  for select to anon, authenticated using (true);

create policy "Users can read own profile" on public.users
  for select to authenticated
  using ((select auth.uid()) = id);
create policy "Users can update own profile" on public.users
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "Users can read own preferences" on public.user_preferences
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can insert own preferences" on public.user_preferences
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update own preferences" on public.user_preferences
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own preferences" on public.user_preferences
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can read own favorites" on public.user_favorites
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert own favorites" on public.user_favorites
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update own favorites" on public.user_favorites
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own favorites" on public.user_favorites
  for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Users can read own commute plans" on public.commute_plans
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert own commute plans" on public.commute_plans
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update own commute plans" on public.commute_plans
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own commute plans" on public.commute_plans
  for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Users can read own trip sessions" on public.trip_sessions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert own trip sessions" on public.trip_sessions
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update own trip sessions" on public.trip_sessions
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own trip sessions" on public.trip_sessions
  for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Users can read own device tokens" on public.device_tokens
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert own device tokens" on public.device_tokens
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update own device tokens" on public.device_tokens
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete own device tokens" on public.device_tokens
  for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Users can read own notification logs" on public.notification_logs
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can mark own notifications opened" on public.notification_logs
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can read own reports" on public.user_reports
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can submit pending reports" on public.user_reports
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and status = 'pending'
    and created_at between (now() - interval '5 minutes') and (now() + interval '5 minutes')
    and expires_at > now()
    and expires_at <= (now() + interval '30 days')
  );

revoke all on table
  public.users,
  public.user_preferences,
  public.operators,
  public.lines,
  public.stations,
  public.station_lines,
  public.trips,
  public.stop_times,
  public.vehicle_positions,
  public.trip_updates,
  public.service_alerts,
  public.transfer_rules,
  public.nearby_places,
  public.user_favorites,
  public.commute_plans,
  public.trip_sessions,
  public.device_tokens,
  public.notification_logs,
  public.user_reports
from public, anon, authenticated;

grant select on table
  public.operators,
  public.lines,
  public.stations,
  public.station_lines,
  public.trips,
  public.stop_times,
  public.vehicle_positions,
  public.trip_updates,
  public.service_alerts,
  public.transfer_rules,
  public.nearby_places
to anon, authenticated;

grant select on table public.users to authenticated;
grant update (display_name, avatar_url) on table public.users to authenticated;
grant select, insert, update, delete on table public.user_preferences to authenticated;
grant select, insert, update, delete on table public.user_favorites to authenticated;
grant select, insert, update, delete on table public.commute_plans to authenticated;
grant select, insert, update, delete on table public.trip_sessions to authenticated;
grant select, insert, update, delete on table public.device_tokens to authenticated;
grant select on table public.notification_logs to authenticated;
grant update (opened_at) on table public.notification_logs to authenticated;
grant select, insert on table public.user_reports to authenticated;

grant all on table
  public.users,
  public.user_preferences,
  public.operators,
  public.lines,
  public.stations,
  public.station_lines,
  public.trips,
  public.stop_times,
  public.vehicle_positions,
  public.trip_updates,
  public.service_alerts,
  public.transfer_rules,
  public.nearby_places,
  public.user_favorites,
  public.commute_plans,
  public.trip_sessions,
  public.device_tokens,
  public.notification_logs,
  public.user_reports
to service_role;

-- Publish only streams required by the client. The block remains safe if the
-- local Supabase publication changes or a migration is replayed manually.
alter table public.vehicle_positions replica identity full;
alter table public.trip_updates replica identity full;
alter table public.service_alerts replica identity full;
alter table public.trip_sessions replica identity full;
alter table public.notification_logs replica identity full;

do $$
declare
  v_table text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach v_table in array array[
      'vehicle_positions',
      'trip_updates',
      'service_alerts',
      'trip_sessions',
      'notification_logs'
    ]
    loop
      if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = v_table
      ) then
        execute format('alter publication supabase_realtime add table public.%I', v_table);
      end if;
    end loop;
  end if;
end;
$$;

comment on table public.users is
  'Application profiles keyed by auth.users; not a replacement for Supabase Auth.';
comment on column public.stop_times.scheduled_arrival is
  'Offset from the service date, represented as interval so GTFS values after 24:00 remain valid.';
comment on column public.vehicle_positions.accuracy_status is
  'Required UI truth label: real_time, near_real_time, estimated, or unavailable.';
comment on table public.user_reports is
  'Community reports are user-generated and must never be presented as official operator information.';

commit;

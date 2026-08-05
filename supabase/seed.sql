begin;

-- ==========================================================================
-- DATA DEMO LOKAL
-- Seluruh record di file ini bersifat sintetis untuk pengembangan lokal.
-- Jadwal, posisi, gangguan, dan tempat berikut BUKAN data operasional nyata.
-- ==========================================================================

insert into public.operators (
  id, name, operator_type, website, data_source_type, is_active
)
values (
  '10000000-0000-4000-8000-000000000001',
  '[DATA DEMO] Operator Transit Lokal',
  'rail',
  'http://localhost',
  'demo',
  true
)
on conflict (id) do update set
  name = excluded.name,
  operator_type = excluded.operator_type,
  website = excluded.website,
  data_source_type = excluded.data_source_type,
  is_active = excluded.is_active;

insert into public.lines (
  id, operator_id, code, name, color, text_color, transport_mode, is_active
)
values (
  '10000000-0000-4000-8000-000000000011',
  '10000000-0000-4000-8000-000000000001',
  'DEMO-KRL',
  '[DATA DEMO] Jalur Bogor–Sudirman',
  '#147D64',
  '#FFFFFF',
  'rail',
  true
)
on conflict (id) do update set
  operator_id = excluded.operator_id,
  code = excluded.code,
  name = excluded.name,
  color = excluded.color,
  text_color = excluded.text_color,
  transport_mode = excluded.transport_mode,
  is_active = excluded.is_active;

insert into public.lines (
  id, operator_id, code, name, color, text_color, transport_mode, is_active
)
values (
  '10000000-0000-4000-8000-000000000012',
  '10000000-0000-4000-8000-000000000001',
  'DEMO-MRIKPB',
  '[DATA DEMO] Jalur Manggarai–Kampung Bandan',
  '#0064B2',
  '#FFFFFF',
  'rail',
  true
)
on conflict (id) do update set
  operator_id = excluded.operator_id,
  code = excluded.code,
  name = excluded.name,
  color = excluded.color,
  text_color = excluded.text_color,
  transport_mode = excluded.transport_mode,
  is_active = excluded.is_active;

insert into public.stations (
  id, code, name, latitude, longitude, address, wheelchair_accessible, facilities, is_active
)
values
  (
    '10000000-0000-4000-8000-000000000101',
    'DEMO-BOO',
    '[DATA DEMO] Bogor',
    -6.595038,
    106.790588,
    'Alamat contoh lokal — bukan data operasional',
    true,
    '{"toilet": true, "prayer_room": true, "wheelchair_access": true, "data_label": "demo"}'::jsonb,
    true
  ),
  (
    '10000000-0000-4000-8000-000000000102',
    'DEMO-MRI',
    '[DATA DEMO] Manggarai',
    -6.210094,
    106.850357,
    'Alamat contoh lokal — bukan data operasional',
    true,
    '{"toilet": true, "lift": true, "escalator": true, "data_label": "demo"}'::jsonb,
    true
  ),
  (
    '10000000-0000-4000-8000-000000000103',
    'DEMO-SUD',
    '[DATA DEMO] Sudirman',
    -6.202402,
    106.823327,
    'Alamat contoh lokal — bukan data operasional',
    true,
    '{"toilet": true, "lift": true, "integrated_transport": ["walk"], "data_label": "demo"}'::jsonb,
    true
  ),
  (
    '10000000-0000-4000-8000-000000000104',
    'DEMO-KPB',
    '[DATA DEMO] Kampung Bandan',
    -6.128611,
    106.826111,
    'Alamat contoh lokal — bukan data operasional',
    true,
    '{"toilet": true, "data_label": "demo"}'::jsonb,
    true
  )
on conflict (id) do update set
  code = excluded.code,
  name = excluded.name,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  address = excluded.address,
  wheelchair_accessible = excluded.wheelchair_accessible,
  facilities = excluded.facilities,
  is_active = excluded.is_active;

insert into public.station_lines (
  station_id, line_id, stop_order, platform_information
)
values
  (
    '10000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000011',
    1,
    '{"label": "Peron demo 1", "data_label": "demo"}'::jsonb
  ),
  (
    '10000000-0000-4000-8000-000000000102',
    '10000000-0000-4000-8000-000000000011',
    2,
    '{"label": "Peron demo 2", "data_label": "demo"}'::jsonb
  ),
  (
    '10000000-0000-4000-8000-000000000103',
    '10000000-0000-4000-8000-000000000011',
    3,
    '{"label": "Peron demo 1", "data_label": "demo"}'::jsonb
  ),
  (
    '10000000-0000-4000-8000-000000000102',
    '10000000-0000-4000-8000-000000000012',
    1,
    '{"label": "Peron demo 3", "data_label": "demo"}'::jsonb
  ),
  (
    '10000000-0000-4000-8000-000000000104',
    '10000000-0000-4000-8000-000000000012',
    2,
    '{"label": "Peron demo 1", "data_label": "demo"}'::jsonb
  )
on conflict (station_id, line_id) do update set
  stop_order = excluded.stop_order,
  platform_information = excluded.platform_information;

insert into public.trips (
  id, external_trip_id, line_id, service_id, headsign, direction_id,
  trip_number, data_source, service_date
)
values (
  '10000000-0000-4000-8000-000000000201',
  'DEMO-TRIP-001',
  '10000000-0000-4000-8000-000000000011',
  'DEMO_DAILY',
  '[DATA DEMO] Sudirman',
  0,
  'DEMO-001',
  'demo',
  current_date
)
on conflict (id) do update set
  external_trip_id = excluded.external_trip_id,
  line_id = excluded.line_id,
  service_id = excluded.service_id,
  headsign = excluded.headsign,
  direction_id = excluded.direction_id,
  trip_number = excluded.trip_number,
  data_source = excluded.data_source,
  service_date = excluded.service_date;

insert into public.stop_times (
  id, trip_id, station_id, stop_sequence, scheduled_arrival,
  scheduled_departure, pickup_type, drop_off_type
)
values
  (
    '10000000-0000-4000-8000-000000000301',
    '10000000-0000-4000-8000-000000000201',
    '10000000-0000-4000-8000-000000000101',
    1,
    interval '6 hours',
    interval '6 hours 2 minutes',
    0,
    1
  ),
  (
    '10000000-0000-4000-8000-000000000302',
    '10000000-0000-4000-8000-000000000201',
    '10000000-0000-4000-8000-000000000102',
    2,
    interval '6 hours 45 minutes',
    interval '6 hours 48 minutes',
    0,
    0
  ),
  (
    '10000000-0000-4000-8000-000000000303',
    '10000000-0000-4000-8000-000000000201',
    '10000000-0000-4000-8000-000000000103',
    3,
    interval '7 hours',
    interval '7 hours',
    1,
    0
  )
on conflict (id) do update set
  trip_id = excluded.trip_id,
  station_id = excluded.station_id,
  stop_sequence = excluded.stop_sequence,
  scheduled_arrival = excluded.scheduled_arrival,
  scheduled_departure = excluded.scheduled_departure,
  pickup_type = excluded.pickup_type,
  drop_off_type = excluded.drop_off_type;

-- A second line through DEMO-MRI (the first trip's own interchange stop),
-- departing after that trip's arrival there plus a real transfer buffer —
-- exists solely so `search_one_transfer_trips` has a genuine one-transfer
-- journey (DEMO-BOO -> DEMO-MRI -> DEMO-KPB) to find in local dev/tests,
-- not just the two-stop direct trip above.
insert into public.trips (
  id, external_trip_id, line_id, service_id, headsign, direction_id,
  trip_number, data_source, service_date
)
values (
  '10000000-0000-4000-8000-000000000202',
  'DEMO-TRIP-002',
  '10000000-0000-4000-8000-000000000012',
  'DEMO_DAILY',
  '[DATA DEMO] Kampung Bandan',
  0,
  'DEMO-002',
  'demo',
  current_date
)
on conflict (id) do update set
  external_trip_id = excluded.external_trip_id,
  line_id = excluded.line_id,
  service_id = excluded.service_id,
  headsign = excluded.headsign,
  direction_id = excluded.direction_id,
  trip_number = excluded.trip_number,
  data_source = excluded.data_source,
  service_date = excluded.service_date;

insert into public.stop_times (
  id, trip_id, station_id, stop_sequence, scheduled_arrival,
  scheduled_departure, pickup_type, drop_off_type
)
values
  (
    '10000000-0000-4000-8000-000000000304',
    '10000000-0000-4000-8000-000000000202',
    '10000000-0000-4000-8000-000000000102',
    1,
    interval '6 hours 53 minutes',
    interval '6 hours 55 minutes',
    0,
    1
  ),
  (
    '10000000-0000-4000-8000-000000000305',
    '10000000-0000-4000-8000-000000000202',
    '10000000-0000-4000-8000-000000000104',
    2,
    interval '7 hours 15 minutes',
    interval '7 hours 15 minutes',
    1,
    0
  )
on conflict (id) do update set
  trip_id = excluded.trip_id,
  station_id = excluded.station_id,
  stop_sequence = excluded.stop_sequence,
  scheduled_arrival = excluded.scheduled_arrival,
  scheduled_departure = excluded.scheduled_departure,
  pickup_type = excluded.pickup_type,
  drop_off_type = excluded.drop_off_type;

insert into public.vehicle_positions (
  id, trip_id, vehicle_id, latitude, longitude, bearing, speed,
  current_station_id, next_station_id, status, recorded_at, source, accuracy_status
)
values (
  '10000000-0000-4000-8000-000000000401',
  '10000000-0000-4000-8000-000000000201',
  'DEMO-VEHICLE-001',
  -6.210094,
  106.850357,
  270,
  0,
  '10000000-0000-4000-8000-000000000102',
  '10000000-0000-4000-8000-000000000103',
  'stopped_at',
  now(),
  'demo',
  'estimated'
)
on conflict (id) do update set
  trip_id = excluded.trip_id,
  vehicle_id = excluded.vehicle_id,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  bearing = excluded.bearing,
  speed = excluded.speed,
  current_station_id = excluded.current_station_id,
  next_station_id = excluded.next_station_id,
  status = excluded.status,
  recorded_at = excluded.recorded_at,
  source = excluded.source,
  accuracy_status = excluded.accuracy_status;

insert into public.trip_updates (
  id, trip_id, station_id, arrival_delay_seconds, departure_delay_seconds,
  predicted_arrival, predicted_departure
)
values (
  '10000000-0000-4000-8000-000000000402',
  '10000000-0000-4000-8000-000000000201',
  '10000000-0000-4000-8000-000000000103',
  120,
  120,
  date_trunc('day', now()) + interval '7 hours 2 minutes',
  date_trunc('day', now()) + interval '7 hours 2 minutes'
)
on conflict (id) do update set
  trip_id = excluded.trip_id,
  station_id = excluded.station_id,
  arrival_delay_seconds = excluded.arrival_delay_seconds,
  departure_delay_seconds = excluded.departure_delay_seconds,
  predicted_arrival = excluded.predicted_arrival,
  predicted_departure = excluded.predicted_departure;

insert into public.service_alerts (
  id, operator_id, line_id, station_id, title, description, severity,
  starts_at, ends_at, source, is_official
)
values (
  '10000000-0000-4000-8000-000000000501',
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000011',
  null,
  '[DATA DEMO] Simulasi keterlambatan',
  'Ini hanya contoh gangguan lokal untuk menguji tampilan dan bukan informasi resmi.',
  'warning',
  now() - interval '15 minutes',
  now() + interval '2 hours',
  'demo',
  false
)
on conflict (id) do update set
  operator_id = excluded.operator_id,
  line_id = excluded.line_id,
  station_id = excluded.station_id,
  title = excluded.title,
  description = excluded.description,
  severity = excluded.severity,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  source = excluded.source,
  is_official = excluded.is_official;

insert into public.transfer_rules (
  id, from_station_id, to_station_id, minimum_transfer_seconds,
  walking_distance, accessibility_notes, instructions
)
values (
  '10000000-0000-4000-8000-000000000601',
  '10000000-0000-4000-8000-000000000102',
  '10000000-0000-4000-8000-000000000102',
  300,
  180,
  '[DATA DEMO] Jalur akses contoh tersedia.',
  '[DATA DEMO] Ikuti papan petunjuk lokal untuk simulasi perpindahan peron.'
)
on conflict (id) do update set
  from_station_id = excluded.from_station_id,
  to_station_id = excluded.to_station_id,
  minimum_transfer_seconds = excluded.minimum_transfer_seconds,
  walking_distance = excluded.walking_distance,
  accessibility_notes = excluded.accessibility_notes,
  instructions = excluded.instructions;

insert into public.nearby_places (
  id, station_id, name, category, latitude, longitude, distance_meters,
  walking_duration_minutes, address, description, source,
  source_external_id, last_verified_at
)
values (
  '10000000-0000-4000-8000-000000000701',
  '10000000-0000-4000-8000-000000000103',
  '[DATA DEMO] Taman Contoh',
  'park',
  -6.203000,
  106.822900,
  250,
  4,
  'Alamat sintetis untuk pengembangan lokal',
  'Tempat sintetis untuk menguji daftar destinasi di sekitar stasiun.',
  'demo',
  'DEMO-PLACE-001',
  now()
)
on conflict (id) do update set
  station_id = excluded.station_id,
  name = excluded.name,
  category = excluded.category,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  distance_meters = excluded.distance_meters,
  walking_duration_minutes = excluded.walking_duration_minutes,
  address = excluded.address,
  description = excluded.description,
  source = excluded.source,
  source_external_id = excluded.source_external_id,
  last_verified_at = excluded.last_verified_at;

commit;

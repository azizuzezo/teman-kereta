-- ============================================================================
-- Saklar jadwal: beberapa "set jadwal" hidup berdampingan di database, dan satu
-- tombol (halaman Jadwal di admin, atau fungsi switch_schedule) menentukan set
-- mana yang dilihat pengguna. Tanpa build ulang aplikasi.
--
-- Kenapa: jadwal GAPEKA 2026 berlaku 1 Desember. Dulu rencananya import beberapa
-- hari sebelumnya lalu hapus jadwal lama lewat SQL manual. Sekarang:
--   1. Import GAPEKA kapan saja dengan set `gapeka2026` (tidak terlihat pengguna).
--   2. Periksa hasilnya di halaman Jadwal.
--   3. Tekan "Jadwalkan 1 Desember" (otomatis berganti pukul 00:00 WIB) atau
--      "Ganti sekarang". Tombol yang sama mengembalikan ke jadwal lama.
--
-- Cara kerja: trips.schedule_set menandai set tiap perjalanan (bawaan `lama`,
-- jadi seluruh data sekarang tetap berlaku). schedule_control menyimpan set aktif
-- dan satu penggantian terjadwal. current_schedule_set() membacanya tiap
-- pemanggilan dengan jam server, sehingga penggantian terjadwal berlaku tepat
-- waktunya tanpa cron. Tiga RPC jadwal dan estimasi posisi kereta hanya membaca
-- set yang aktif.
--
-- Syarat: terapkan SETELAH 20261118090000_gapeka_estimated_times.sql (fungsi di
-- bawah adalah salinannya dengan satu filter tambahan; bentuk keluaran tidak
-- berubah, jadi `create or replace` cukup).
-- ============================================================================

alter table public.trips
  add column if not exists schedule_set text not null default 'lama';

comment on column public.trips.schedule_set is
  'Set jadwal tempat perjalanan ini berada (lama, gapeka2026, ...). Hanya set yang aktif menurut current_schedule_set() yang dilihat pengguna.';

create index if not exists trips_schedule_set_date_idx
  on public.trips (schedule_set, service_date);

-- ---------------------------------------------------------------------------
-- Kontrol: satu baris
-- ---------------------------------------------------------------------------

create table if not exists public.schedule_control (
  id smallint primary key check (id = 1),
  active_set text not null default 'lama',
  previous_set text,
  next_set text,
  switch_at timestamptz,
  updated_at timestamptz not null default now(),
  updated_by text,
  check ((next_set is null) = (switch_at is null))
);

insert into public.schedule_control (id) values (1) on conflict (id) do nothing;

alter table public.schedule_control enable row level security;
revoke all on table public.schedule_control from public, anon, authenticated;
grant all on table public.schedule_control to service_role;

comment on table public.schedule_control is
  'Satu baris: set jadwal aktif, dan satu penggantian terjadwal (next_set pada switch_at). Diubah lewat switch_schedule() dan cancel_scheduled_switch(), bukan langsung.';

create table if not exists public.schedule_switch_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor text,
  action text not null check (action in ('switch', 'schedule', 'cancel')),
  from_set text,
  to_set text,
  effective_at timestamptz
);

alter table public.schedule_switch_log enable row level security;
revoke all on table public.schedule_switch_log from public, anon, authenticated;
grant all on table public.schedule_switch_log to service_role;

-- ---------------------------------------------------------------------------
-- Set yang berlaku saat ini. SECURITY DEFINER supaya pengguna anonim bisa
-- memanggilnya tanpa boleh membaca tabel kontrol.
-- ---------------------------------------------------------------------------

create or replace function public.current_schedule_set()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select case
              when c.next_set is not null and c.switch_at <= now() then c.next_set
              else c.active_set
            end
     from public.schedule_control c
     where c.id = 1),
    'lama'
  );
$$;

revoke all on function public.current_schedule_set() from public;
grant execute on function public.current_schedule_set() to anon, authenticated, service_role;

-- Rentang tanggal perjalanan pada set yang aktif. Aplikasi memakainya untuk
-- menggeser jadwal ke hari ini bila jendela import sudah lewat; dulu aplikasi
-- membaca seluruh tabel trips, yang akan mencampur set.
create or replace function public.get_schedule_window()
returns table (first_date date, last_date date, schedule_set text)
language sql
stable
security definer
set search_path = ''
as $$
  select min(t.service_date), max(t.service_date), public.current_schedule_set()
  from public.trips t
  where t.schedule_set = public.current_schedule_set();
$$;

revoke all on function public.get_schedule_window() from public;
grant execute on function public.get_schedule_window() to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Status untuk halaman admin (hanya service_role)
-- ---------------------------------------------------------------------------

create or replace function public.get_schedule_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'effective_set', public.current_schedule_set(),
    'active_set', c.active_set,
    'previous_set', c.previous_set,
    'next_set', c.next_set,
    'switch_at', c.switch_at,
    'updated_at', c.updated_at,
    'updated_by', c.updated_by,
    'now', now(),
    'sets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'schedule_set', s.schedule_set,
        'trips', s.trips,
        'first_date', s.first_date,
        'last_date', s.last_date,
        'lines', s.lines
      ) order by s.schedule_set)
      from (
        select t.schedule_set,
               count(*) as trips,
               min(t.service_date) as first_date,
               max(t.service_date) as last_date,
               count(distinct t.line_id) as lines
        from public.trips t
        group by t.schedule_set
      ) s
    ), '[]'::jsonb),
    'log', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.at desc)
      from (select at, actor, action, from_set, to_set, effective_at
            from public.schedule_switch_log order by at desc limit 10) l
    ), '[]'::jsonb)
  )
  from public.schedule_control c
  where c.id = 1;
$$;

revoke all on function public.get_schedule_status() from public, anon, authenticated;
grant execute on function public.get_schedule_status() to service_role;

-- ---------------------------------------------------------------------------
-- Ganti set jadwal. p_at <= sekarang: berlaku seketika. p_at di masa depan:
-- dijadwalkan dan berlaku sendiri pada waktu itu. Set tujuan harus punya
-- perjalanan, supaya tidak ada yang mengosongkan jadwal karena salah ketik.
-- ---------------------------------------------------------------------------

create or replace function public.switch_schedule(
  p_set text,
  p_at timestamptz default now(),
  p_actor text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current text := public.current_schedule_set();
  v_now timestamptz := now();
  v_trips bigint;
begin
  if p_set is null or btrim(p_set) = '' then
    raise exception 'Nama set jadwal wajib diisi';
  end if;
  select count(*) into v_trips from public.trips where schedule_set = p_set;
  if v_trips = 0 then
    raise exception 'Set jadwal "%" belum punya perjalanan. Import dulu sebelum mengganti.', p_set;
  end if;

  -- Penggantian terjadwal yang sudah jatuh tempo dilunasi dulu supaya
  -- active_set mencerminkan kenyataan sebelum diubah lagi.
  update public.schedule_control
     set active_set = next_set, next_set = null, switch_at = null
   where id = 1 and next_set is not null and switch_at <= v_now;

  if p_at is null or p_at <= v_now then
    if p_set <> v_current then
      update public.schedule_control
         set previous_set = v_current,
             active_set = p_set,
             next_set = null,
             switch_at = null,
             updated_at = v_now,
             updated_by = p_actor
       where id = 1;
    else
      -- Sudah aktif; hanya batalkan penggantian terjadwal yang tersisa.
      update public.schedule_control
         set next_set = null, switch_at = null, updated_at = v_now, updated_by = p_actor
       where id = 1;
    end if;
    insert into public.schedule_switch_log (actor, action, from_set, to_set, effective_at)
    values (p_actor, 'switch', v_current, p_set, v_now);
  else
    update public.schedule_control
       set next_set = p_set,
           switch_at = p_at,
           updated_at = v_now,
           updated_by = p_actor
     where id = 1;
    insert into public.schedule_switch_log (actor, action, from_set, to_set, effective_at)
    values (p_actor, 'schedule', v_current, p_set, p_at);
  end if;

  return public.get_schedule_status();
end;
$$;

revoke all on function public.switch_schedule(text, timestamptz, text) from public, anon, authenticated;
grant execute on function public.switch_schedule(text, timestamptz, text) to service_role;

create or replace function public.cancel_scheduled_switch(p_actor text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pending text;
begin
  select next_set into v_pending from public.schedule_control
   where id = 1 and next_set is not null and switch_at > now();
  if v_pending is not null then
    update public.schedule_control
       set next_set = null, switch_at = null, updated_at = now(), updated_by = p_actor
     where id = 1;
    insert into public.schedule_switch_log (actor, action, from_set, to_set)
    values (p_actor, 'cancel', public.current_schedule_set(), v_pending);
  end if;
  return public.get_schedule_status();
end;
$$;

revoke all on function public.cancel_scheduled_switch(text) from public, anon, authenticated;
grant execute on function public.cancel_scheduled_switch(text) to service_role;

-- ---------------------------------------------------------------------------
-- RPC jadwal: salinan dari 20261118090000 dengan satu filter tambahan,
-- t.schedule_set = current_schedule_set().
-- ---------------------------------------------------------------------------

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
  scheduled_departure timestamptz,
  is_estimated boolean,
  service_id text
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
    (t.service_date + st.scheduled_departure) at time zone s.timezone as scheduled_departure,
    st.is_estimated,
    t.service_id
  from public.stop_times st
  join public.stations s on s.id = st.station_id
  join public.trips t on t.id = st.trip_id
  join public.lines l on l.id = t.line_id
  where s.code = p_station_code
    and s.is_active
    and t.data_source is not null
    and t.schedule_set = public.current_schedule_set()
    and (t.service_date + st.scheduled_departure) at time zone s.timezone >= p_from
  order by scheduled_departure asc
  limit greatest(1, least(p_limit, 100));
$$;

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
  destination_arrival timestamptz,
  origin_is_estimated boolean,
  destination_is_estimated boolean,
  service_id text
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
    (t.service_date + d.scheduled_arrival) at time zone ds.timezone as destination_arrival,
    o.is_estimated as origin_is_estimated,
    d.is_estimated as destination_is_estimated,
    t.service_id
  from public.trips t
  join public.lines l on l.id = t.line_id
  join public.stop_times o on o.trip_id = t.id
  join public.stations os on os.id = o.station_id and os.code = p_origin_code and os.is_active
  join public.stop_times d on d.trip_id = t.id
  join public.stations ds on ds.id = d.station_id and ds.code = p_destination_code and ds.is_active
  where o.stop_sequence < d.stop_sequence
    and t.schedule_set = public.current_schedule_set()
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
  inbound_destination_arrival timestamptz,
  origin_is_estimated boolean,
  transfer_arrival_is_estimated boolean,
  transfer_departure_is_estimated boolean,
  destination_is_estimated boolean,
  first_service_id text,
  second_service_id text
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
      t.service_id,
      o.stop_sequence as origin_sequence,
      tr.stop_sequence as transfer_sequence,
      tr.station_id as transfer_station_id,
      ts.code as transfer_station_code,
      (t.service_date + o.scheduled_departure) at time zone os.timezone as origin_departure,
      (t.service_date + tr.scheduled_arrival) at time zone ts.timezone as transfer_arrival,
      o.is_estimated as origin_is_estimated,
      tr.is_estimated as transfer_arrival_is_estimated
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
    where t.schedule_set = public.current_schedule_set()
      and (t.service_date + o.scheduled_departure) at time zone os.timezone >= p_from
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
      t.service_id,
      tr.stop_sequence as transfer_sequence,
      d.stop_sequence as destination_sequence,
      tr.station_id as transfer_station_id,
      (t.service_date + tr.scheduled_departure) at time zone ts.timezone as transfer_departure,
      (t.service_date + d.scheduled_arrival) at time zone ds.timezone as destination_arrival,
      tr.is_estimated as transfer_departure_is_estimated,
      d.is_estimated as destination_is_estimated
    from public.trips t
    join public.lines l on l.id = t.line_id
    join public.stop_times d on d.trip_id = t.id
    join public.stations ds on ds.id = d.station_id and ds.code = p_destination_code and ds.is_active
    join public.stop_times tr
      on tr.trip_id = t.id and tr.stop_sequence < d.stop_sequence
    join public.stations ts on ts.id = tr.station_id and ts.is_active
    where t.schedule_set = public.current_schedule_set()
      and (t.service_date + d.scheduled_arrival) at time zone ds.timezone >= p_from
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
    ib.destination_arrival,
    ob.origin_is_estimated,
    ob.transfer_arrival_is_estimated,
    ib.transfer_departure_is_estimated,
    ib.destination_is_estimated,
    ob.service_id,
    ib.service_id
  from outbound ob
  join inbound ib
    on ib.transfer_station_id = ob.transfer_station_id
    and ib.trip_id <> ob.trip_id
    and ib.transfer_departure >= ob.transfer_arrival + make_interval(secs => p_transfer_buffer_seconds)
  order by ob.origin_departure asc, (ib.destination_arrival - ob.origin_departure) asc
  limit greatest(1, least(p_limit, 20));
$$;

-- ---------------------------------------------------------------------------
-- Estimasi posisi kereta: salinan dari 20260805170000 dengan filter set yang sama.
-- ---------------------------------------------------------------------------

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
      and t.schedule_set = public.current_schedule_set()
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

-- Grant lama (anon/authenticated untuk RPC jadwal, service_role untuk estimasi)
-- tidak berubah karena fungsi hanya di-replace.

-- ---------------------------------------------------------------------------
-- Import GTFS: bawa label set per baris (`schedule_set`; kosong = `lama`).
-- Salinan dari 20260805150000 dengan satu kolom tambahan.
-- ---------------------------------------------------------------------------

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
    external_trip_id, line_id, service_id, headsign, trip_number, data_source, service_date, schedule_set
  )
  select
    r.external_trip_id,
    r.line_id,
    r.service_id,
    r.headsign,
    r.trip_number,
    r.data_source,
    r.service_date,
    coalesce(nullif(btrim(r.schedule_set), ''), 'lama')
  from jsonb_to_recordset(p_trips) as r(
    external_trip_id text,
    line_id uuid,
    service_id text,
    headsign text,
    trip_number text,
    data_source text,
    service_date date,
    schedule_set text
  )
  on conflict (line_id, external_trip_id, service_date) where external_trip_id is not null
  do update set
    service_id = excluded.service_id,
    headsign = excluded.headsign,
    trip_number = excluded.trip_number,
    data_source = excluded.data_source,
    schedule_set = excluded.schedule_set,
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
    service_date date,
    schedule_set text
  ) on r.line_id = t.line_id
    and r.external_trip_id = t.external_trip_id
    and r.service_date = t.service_date;
end;
$$;

revoke all on function public.import_gtfs_trips(jsonb) from public, anon, authenticated;
grant execute on function public.import_gtfs_trips(jsonb) to service_role;

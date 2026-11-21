-- ============================================================================
-- Posisi kereta langsung (train_live): satu baris per kereta, diperbarui tiap
-- ada laporan, bukan sekali semenit.
--
-- Masalah sebelumnya: laporan penumpang masuk ke crowd_position_reports (tulis
-- saja), lalu pg_cron menjalankan refresh_crowd_vehicle_positions() sekali per
-- menit, yang menghapus semua baris `crowd_sourced` di vehicle_positions dan
-- memasukkannya lagi. Hasilnya di peta: kereta pengguna lain meloncat sekali
-- semenit, dan tiap loncatan datang sebagai hapus + sisip (id baru).
--
-- Sekarang:
--   1. Laporan boleh masuk tiap 4 detik per perangkat (dulu 15 detik) dan
--      membawa kecepatan dan arah GPS (kolom opsional).
--   2. Trigger pada crowd_position_reports memperbarui satu baris per kereta di
--      `train_live` (upsert, id tetap). Supabase Realtime mengirim perubahan itu
--      ke aplikasi dalam sekitar satu detik.
--   3. `train_live` hanya berisi posisi, arah, kecepatan, tujuan (`headsign`)
--      dan layanan (`relation`). Tidak ada device_session_id, tidak ada
--      identitas apa pun. Siapa pun boleh membaca, tidak ada yang boleh menulis
--      langsung.
--   4. Baris lebih dari 3 menit dihapus tiap menit.
--
-- Aplikasi tetap jalan bila migrasi ini belum diterapkan: ia kembali membaca
-- `vehicle_positions` seperti sebelumnya dan mengulang laporan tanpa kolom baru.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Kolom opsional di laporan, dan batas laju 4 detik
-- ---------------------------------------------------------------------------

alter table public.crowd_position_reports
  add column if not exists speed real check (speed is null or (speed >= 0 and speed <= 60)),
  add column if not exists bearing real check (bearing is null or (bearing >= 0 and bearing < 360));

create or replace function public.crowd_position_report_rate_ok(p_device_session_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.crowd_position_reports
    where device_session_id = p_device_session_id
      and created_at > now() - interval '4 seconds'
  )
$$;

comment on function public.crowd_position_report_rate_ok is
  'RLS insert guard for crowd_position_reports: at most one report per device_session_id every 4 seconds (client cadence is 5s).';

-- Pagar geografi dilebarkan dari Jabodetabek saja ke Jawa bagian tengah dan
-- barat, supaya laporan KRL Yogyakarta-Solo (lintang sekitar -7.8) tidak
-- ditolak diam-diam. Tetap kotak kasar: di luar itu pasti bukan KRL.
drop policy if exists "Anyone can report their own position"
  on public.crowd_position_reports;

create policy "Anyone can report their own position"
  on public.crowd_position_reports
  for insert
  to anon, authenticated
  with check (
    public.crowd_position_report_rate_ok(device_session_id)
    and latitude between -8.3 and -5.9
    and longitude between 106.0 and 111.2
  );

-- ---------------------------------------------------------------------------
-- 2. train_live
-- ---------------------------------------------------------------------------

create table if not exists public.train_live (
  train_key text primary key,
  external_trip_id text not null,
  service_date date not null,
  latitude double precision not null,
  longitude double precision not null,
  bearing real,
  speed real,
  headsign text,
  relation text,
  recorded_at timestamptz not null,
  updated_at timestamptz not null default now()
);

comment on table public.train_live is
  'Satu baris per kereta yang sedang dilaporkan penumpang: posisi, arah, kecepatan, tujuan. Tanpa identitas. Diisi trigger dari crowd_position_reports, dibaca aplikasi lewat Realtime.';

create index if not exists train_live_updated_idx
  on public.train_live (updated_at);

alter table public.train_live enable row level security;

drop policy if exists "Anyone can read live trains" on public.train_live;
create policy "Anyone can read live trains"
  on public.train_live
  for select
  to anon, authenticated
  using (true);

revoke all on table public.train_live from public;
grant select on table public.train_live to anon, authenticated;
grant all on table public.train_live to service_role;

-- ---------------------------------------------------------------------------
-- 3. Trigger: laporan masuk -> baris kereta diperbarui
-- ---------------------------------------------------------------------------

create or replace function public.apply_crowd_ping_to_train_live()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text := new.external_trip_id || '|' || new.service_date::text;
  v_prev public.train_live%rowtype;
  v_bearing real := new.bearing;
  v_speed real := new.speed;
  v_dx double precision;
  v_dy double precision;
  v_dist double precision;
  v_dt double precision;
begin
  select * into v_prev from public.train_live where train_key = v_key;

  if found then
    -- Laporan yang lebih tua dari yang sudah tercatat (urutan tiba terbalik,
    -- atau dua penumpang di kereta yang sama) tidak boleh memundurkan kereta.
    if new.reported_at <= v_prev.recorded_at then
      return new;
    end if;

    v_dy := (new.latitude - v_prev.latitude) * 110574.0;
    v_dx := (new.longitude - v_prev.longitude) * 110700.0;
    v_dist := sqrt(v_dx * v_dx + v_dy * v_dy);
    v_dt := extract(epoch from (new.reported_at - v_prev.recorded_at));

    if v_speed is null and v_dt >= 1 then
      v_speed := least(v_dist / v_dt, 45)::real;
    end if;
    if v_bearing is null then
      if v_dist >= 12 then
        v_bearing := mod(
          (degrees(atan2(v_dx, v_dy)) + 360)::numeric,
          360::numeric
        )::real;
      else
        -- Hampir diam: pertahankan arah terakhir.
        v_bearing := v_prev.bearing;
      end if;
    end if;
  end if;

  insert into public.train_live (
    train_key, external_trip_id, service_date, latitude, longitude,
    bearing, speed, headsign, relation, recorded_at, updated_at
  )
  values (
    v_key, new.external_trip_id, new.service_date, new.latitude, new.longitude,
    v_bearing, v_speed, new.headsign, new.relation, new.reported_at, now()
  )
  on conflict (train_key) do update set
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    bearing = excluded.bearing,
    speed = excluded.speed,
    headsign = coalesce(excluded.headsign, public.train_live.headsign),
    relation = coalesce(excluded.relation, public.train_live.relation),
    recorded_at = excluded.recorded_at,
    updated_at = excluded.updated_at;

  return new;
end;
$$;

revoke all on function public.apply_crowd_ping_to_train_live() from public, anon, authenticated;

drop trigger if exists crowd_ping_to_train_live on public.crowd_position_reports;
create trigger crowd_ping_to_train_live
  after insert on public.crowd_position_reports
  for each row execute function public.apply_crowd_ping_to_train_live();

-- ---------------------------------------------------------------------------
-- 4. Retensi dan Realtime
-- ---------------------------------------------------------------------------

select cron.schedule(
  'prune_train_live',
  '* * * * *',
  $$delete from public.train_live where updated_at < now() - interval '3 minutes';$$
);

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'train_live'
     ) then
    alter publication supabase_realtime add table public.train_live;
  end if;
end;
$$;

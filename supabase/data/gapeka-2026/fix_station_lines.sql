-- GAPEKA 2026: lengkapi station_lines untuk stasiun yang hanya dilewati perjalanan non-kanonik.
--
-- Importer menurunkan station_lines dari perjalanan TERPANJANG tiap rute. Stasiun yang hanya ada di pola lain
-- (mis. Jombang, Mojokerto, Krian di lintas Penataran/Dhoho/Jenggala, dan Bandara di lintas BST) tidak dapat baris.
-- Aplikasi menganggap stasiun tanpa lini sebagai Jabodetabek, sehingga tab Jabodetabek melebar sampai Jawa Timur dan
-- kamera peta berpindah ke Jawa Tengah.
--
-- Perbaikan: beri tiap stasiun itu baris untuk lini yang melayaninya. stop_order (hanya dipakai untuk mengurutkan)
-- diambil dari tetangga sebelumnya di perjalanan yang sama; nilai lini yang terkena dijarangkan 100x supaya stasiun
-- baru dapat urutan unik di antara tetangganya. Idempoten: tanpa stasiun yang kurang, tidak ada yang berubah.
-- Hanya menambah baris (dan menjarangkan stop_order lini yang terkena); tidak menghapus apa pun.

do $$
begin
  drop table if exists _sl_add;
  create temp table _sl_add (
    station_id uuid not null, line_id uuid not null, trip_id uuid not null, seq integer not null, prev_ord integer
  ) on commit drop;

  insert into _sl_add (station_id, line_id, trip_id, seq)
  select distinct on (m.station_id, m.line_id) m.station_id, m.line_id, t.id, x.stop_sequence
  from (
    select distinct x.station_id, t.line_id
    from public.stop_times x
    join public.trips t on t.id = x.trip_id
    where t.schedule_set = 'gapeka2026'
      and not exists (select 1 from public.station_lines sl where sl.station_id = x.station_id)
  ) m
  join public.trips t on t.line_id = m.line_id and t.schedule_set = 'gapeka2026' and t.service_date = date '2026-12-01'
  join public.stop_times x on x.trip_id = t.id and x.station_id = m.station_id
  order by m.station_id, m.line_id,
           (select count(*) from public.stop_times y where y.trip_id = t.id) desc, t.id;

  update _sl_add a
     set prev_ord = coalesce((
       select sl.stop_order
       from public.stop_times y
       join public.station_lines sl on sl.station_id = y.station_id and sl.line_id = a.line_id
       where y.trip_id = a.trip_id and y.stop_sequence < a.seq and sl.stop_order is not null
       order by y.stop_sequence desc limit 1), 0);

  update public.station_lines sl
     set stop_order = sl.stop_order * 100, updated_at = now()
   where sl.stop_order is not null
     and sl.line_id in (select distinct line_id from _sl_add);

  insert into public.station_lines (station_id, line_id, stop_order, platform_information)
  select a.station_id, a.line_id,
         a.prev_ord * 100 + row_number() over (partition by a.line_id, a.prev_ord order by a.seq, a.station_id),
         '{}'::jsonb
  from _sl_add a
  on conflict (station_id, line_id) do nothing;
end
$$;

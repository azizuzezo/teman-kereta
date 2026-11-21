-- ============================================================================
-- Pengaman saklar jadwal untuk aplikasi versi lama.
--
-- Aplikasi sebelum saklar membaca tabel `trips` langsung (PostgREST) untuk
-- menghitung "jendela jadwal" (tanggal pertama dan terakhir). Begitu jadwal baru
-- disiapkan di set tersembunyi, jendela itu ikut melebar sampai Desember;
-- aplikasi lama lalu menganggap hari ini berada di dalam jendela, tidak
-- menggeser jadwal, dan keberangkatan jadi kosong.
--
-- Jadi pengguna anonim dan terautentikasi hanya boleh melihat perjalanan pada
-- set yang sedang aktif. service_role (admin dan importer) tetap melihat semua.
-- RPC jadwal sudah memfilter set yang sama, jadi hasilnya tidak berubah.
--
-- Syarat: terapkan setelah 20261122090000_schedule_switch.sql.
-- ============================================================================

drop policy if exists "Public can read trips" on public.trips;

create policy "Public can read trips"
  on public.trips
  for select
  to anon, authenticated
  using (schedule_set = (select public.current_schedule_set()));

comment on policy "Public can read trips" on public.trips is
  'Hanya perjalanan pada set jadwal yang aktif (current_schedule_set()). Set yang disiapkan tersembunyi tidak terlihat sampai diaktifkan.';

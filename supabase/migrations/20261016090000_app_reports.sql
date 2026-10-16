-- Laporan masalah dari aplikasi (Bantuan -> Laporkan masalah) beserta log dan
-- info perangkat, lalu diteruskan otomatis ke support@temankereta.web.id lewat
-- Edge Function `send-report-email` (Cloudflare Email Service).
--
-- Kenapa tabel baru, bukan memperluas public.user_reports:
--   * user_reports adalah laporan KONDISI KERETA/STASIUN dari komunitas
--     (report_type enum kepadatan/AC/lift/..., line/station/trip, expires_at
--     default 6 jam, halaman moderasi /user-reports di admin). Laporan masalah
--     aplikasi bukan konten komunitas, tidak boleh kedaluwarsa, dan membawa log
--     hingga 200 KB yang akan mencemari halaman moderasi itu.
--   * user_reports.user_id NOT NULL, sedangkan laporan bug boleh dikirim tanpa
--     akun (mis. gagal login).
--   * Aplikasi saat ini tidak menulis ke user_reports (hanya tabel Drift lokal),
--     jadi tidak ada data lama yang perlu dimigrasikan.
--
-- Skema dibaca oleh panel admin lewat service role (RLS dilewati). Klien hanya
-- boleh INSERT; tidak ada kebijakan SELECT/UPDATE/DELETE untuk anon/authenticated.
-- Migrasi ini BELUM diterapkan ke database mana pun.

create table public.app_reports (
  -- Dibuat di klien (uuid v4) supaya percobaan ulang setelah koneksi putus
  -- tidak membuat baris ganda (insert kedua gagal 23505 dan dianggap sukses).
  -- 8 karakter pertama (huruf besar) = nomor laporan yang dilihat pengguna.
  id uuid primary key default gen_random_uuid(),
  -- Diisi dari JWT oleh default; klien tidak mengirimnya. Null = tidak masuk.
  user_id uuid default auth.uid() references public.users (id) on delete cascade,

  category text not null
    check (category in ('schedule', 'notification', 'map', 'forum', 'account', 'other')),
  message text not null check (char_length(message) between 10 and 4000),
  -- Hanya terisi kalau pengguna mencentang "sertakan email untuk dihubungi".
  contact_email text
    check (contact_email is null or (char_length(contact_email) <= 254 and contact_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]{2,}$')),

  app_version text check (app_version is null or char_length(app_version) <= 40),
  build_number text check (build_number is null or char_length(build_number) <= 20),
  platform text check (platform is null or char_length(platform) <= 40),
  os_version text check (os_version is null or char_length(os_version) <= 80),
  device_model text check (device_model is null or char_length(device_model) <= 120),

  -- Ringkasan terstruktur (app/device/status/log) -- lihat
  -- DiagnosticsFormatter.toJson di lib/core/diagnostics/diagnostics_report.dart.
  diagnostics jsonb not null default '{}'::jsonb
    check (octet_length(diagnostics::text) <= 50000),
  -- Log aplikasi (sudah disamarkan di perangkat: JWT, token, email, telepon).
  -- Null kalau pengguna mematikan "Sertakan log aplikasi".
  log_text text check (log_text is null or char_length(log_text) <= 200000),
  -- Dibaca panel admin untuk daftar laporan tanpa menarik log penuh (sampai
  -- 200 KB per baris) hanya untuk menampilkan lencana.
  has_log boolean generated always as (log_text is not null) stored,

  -- Penanganan oleh tim.
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved', 'dismissed')),

  -- Pengiriman email ke support.
  email_status text not null default 'pending'
    check (email_status in ('pending', 'sent', 'failed')),
  email_sent_at timestamptz,
  email_error text check (email_error is null or char_length(email_error) <= 1000),
  email_attempts integer not null default 0,
  -- Dicatat oleh database setiap kali pengiriman ditembakkan (bukan oleh Edge
  -- Function), supaya panggilan yang tidak pernah sampai (secret salah, fungsi
  -- belum di-deploy) tetap berhenti di batasnya dan dua jalur (trigger + cron)
  -- tidak menembak baris yang sama bersamaan.
  email_dispatches integer not null default 0,
  email_last_dispatch_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.app_reports is
  'Laporan masalah dari aplikasi (kategori, pesan, info perangkat, log). Klien hanya INSERT; dibaca admin lewat service role. Diteruskan ke email support oleh Edge Function send-report-email.';

create index app_reports_created_idx on public.app_reports (created_at desc);
create index app_reports_user_created_idx on public.app_reports (user_id, created_at desc)
  where user_id is not null;
create index app_reports_email_backlog_idx on public.app_reports (created_at)
  where email_status <> 'sent';

create trigger app_reports_set_updated_at before update on public.app_reports
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS: insert saja. Tidak ada policy select/update/delete untuk klien.
-- ---------------------------------------------------------------------------

alter table public.app_reports enable row level security;

revoke all on public.app_reports from anon, authenticated;
grant insert on public.app_reports to anon, authenticated;

create policy "Anyone can submit an app report as themselves"
  on public.app_reports
  for insert
  to anon, authenticated
  with check (
    -- Pengguna masuk hanya boleh menulis atas namanya; anon hanya tanpa user_id.
    user_id is not distinct from (select auth.uid())
    and status = 'open'
    and email_status = 'pending'
    and email_sent_at is null
    and email_error is null
    and email_attempts = 0
    and email_dispatches = 0
    and email_last_dispatch_at is null
  );

-- ---------------------------------------------------------------------------
-- BEFORE INSERT: batas laju + bersihkan kolom yang hanya boleh diisi server.
-- ---------------------------------------------------------------------------

create or replace function public.app_reports_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recent integer;
begin
  -- Kolom internal tidak boleh ditentukan klien.
  new.status := 'open';
  new.email_status := 'pending';
  new.email_sent_at := null;
  new.email_error := null;
  new.email_attempts := 0;
  new.email_dispatches := 0;
  new.email_last_dispatch_at := null;
  new.created_at := now();
  new.updated_at := now();

  if new.user_id is not null then
    -- Maksimal 10 laporan per akun per jam.
    select count(*) into recent
      from public.app_reports r
      where r.user_id = new.user_id and r.created_at > now() - interval '1 hour';
    if recent >= 10 then
      raise exception 'Terlalu banyak laporan. Coba lagi nanti.'
        using errcode = '54000';
    end if;
  else
    -- Tanpa akun tidak ada identitas yang bisa dipercaya: batas total 30
    -- laporan anonim per jam untuk seluruh proyek (meredam banjir, bukan
    -- pembatas per pengguna).
    select count(*) into recent
      from public.app_reports r
      where r.user_id is null and r.created_at > now() - interval '1 hour';
    if recent >= 30 then
      raise exception 'Terlalu banyak laporan. Coba lagi nanti.'
        using errcode = '54000';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.app_reports_before_insert() from public, anon, authenticated;

create trigger app_reports_before_insert
  before insert on public.app_reports
  for each row execute function public.app_reports_before_insert();

-- ---------------------------------------------------------------------------
-- AFTER INSERT: tembak Edge Function send-report-email lewat pg_net.
-- Pola yang sama dengan notify_forum_new_post() (20260911120000): URL dan
-- kredensial dari Vault, trigger diam bila Vault belum diisi.
-- Hanya id yang dikirim; fungsi membaca baris aslinya sendiri dengan service
-- role, jadi isi laporan tidak bisa dipalsukan lewat panggilan ke fungsi.
-- ---------------------------------------------------------------------------

create or replace function public.app_reports_post_email_job(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  fn_url text;
  fn_secret text;
  fn_jwt text;
begin
  select decrypted_secret into fn_url
    from vault.decrypted_secrets where name = 'app_report_email_url';
  select decrypted_secret into fn_secret
    from vault.decrypted_secrets where name = 'app_report_email_secret';
  select decrypted_secret into fn_jwt
    from vault.decrypted_secrets where name = 'app_report_email_jwt';

  if fn_url is null or fn_secret is null or fn_jwt is null then
    raise notice 'app_reports: secret Vault belum diisi, email dilewati (email_status tetap pending).';
    return;
  end if;

  -- Klaim baris secara atomik sebelum menembak: hanya satu pemanggil yang
  -- lolos untuk satu jendela 2 menit, dan jumlah tembakan dibatasi 8 kali.
  update public.app_reports
    set email_dispatches = email_dispatches + 1,
        email_last_dispatch_at = now()
    where id = p_id
      and email_status <> 'sent'
      and email_dispatches < 8
      and (email_last_dispatch_at is null
           or email_last_dispatch_at < now() - interval '2 minutes');
  if not found then
    return;
  end if;

  perform net.http_post(
    url := fn_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      -- Gateway Supabase menolak panggilan tanpa JWT; isi dengan anon key
      -- (publik). Otorisasi sebenarnya ada di x-webhook-secret.
      'Authorization', 'Bearer ' || fn_jwt,
      'x-webhook-secret', fn_secret
    ),
    body := jsonb_build_object('id', p_id)
  );
end;
$$;

revoke all on function public.app_reports_post_email_job(uuid) from public, anon, authenticated;

create or replace function public.app_reports_notify_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.app_reports_post_email_job(new.id);
  return new;
exception when others then
  -- Kegagalan pg_net/Vault tidak boleh menggagalkan INSERT laporan: laporan
  -- tetap tersimpan dan dikirim ulang oleh resend_pending_app_report_emails().
  raise warning 'app_reports_notify_email: % (%)', sqlerrm, sqlstate;
  return new;
end;
$$;

revoke all on function public.app_reports_notify_email() from public, anon, authenticated;

create trigger app_reports_notify_email
  after insert on public.app_reports
  for each row execute function public.app_reports_notify_email();

-- Kirim ulang email yang masih pending/failed (pg_net tidak mencoba ulang
-- sendiri). Dipanggil manual atau dijadwalkan pg_cron (lihat SETUP). Hanya
-- service role/postgres yang boleh memanggilnya.
create or replace function public.resend_pending_app_report_emails(p_limit integer default 20)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select id from public.app_reports
    where email_status <> 'sent'
      and created_at < now() - interval '2 minutes'
      and email_attempts < 5
      and email_dispatches < 8
    order by created_at
    limit greatest(p_limit, 0)
  loop
    perform public.app_reports_post_email_job(r.id);
    n := n + 1;
  end loop;
  return n;
end;
$$;

revoke all on function public.resend_pending_app_report_emails(integer) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- SETUP (dijalankan sekali oleh pemilik proyek, bukan bagian dari migrasi)
-- ---------------------------------------------------------------------------
-- 1) Deploy Edge Function dan isi secret-nya (lihat docs/support-reports.md):
--      supabase functions deploy send-report-email
--      supabase secrets set CLOUDFLARE_ACCOUNT_ID=... CLOUDFLARE_API_TOKEN=... \
--        SUPPORT_EMAIL=support@temankereta.web.id WEBHOOK_SECRET=<acak panjang>
--
-- 2) Simpan kredensial pemanggil ke Vault (nilai WEBHOOK_SECRET HARUS sama):
--      select vault.create_secret(
--        'https://<project-ref>.supabase.co/functions/v1/send-report-email',
--        'app_report_email_url');
--      select vault.create_secret('<WEBHOOK_SECRET>', 'app_report_email_secret');
--      select vault.create_secret('<ANON_KEY>', 'app_report_email_jwt');
--
-- 3) Opsional, kirim ulang otomatis tiap 10 menit yang gagal/pending:
--      select cron.schedule('resend-app-report-emails', '*/10 * * * *',
--        $$select public.resend_pending_app_report_emails(20)$$);
--
-- Untuk mematikan pengiriman email sementara tanpa menghapus apa pun:
--      drop trigger app_reports_notify_email on public.app_reports;
--
-- Retensi: belum ada penghapusan otomatis. Laporan ikut terhapus saat akun
-- pelapor dihapus (on delete cascade); laporan tanpa akun perlu dihapus manual
-- atau dengan job pg_cron bila pemilik menetapkan masa simpan.
-- ============================================================================

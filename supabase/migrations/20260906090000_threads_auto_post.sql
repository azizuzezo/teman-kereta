-- Auto-posting ke akun Threads (Meta) milik Teman Kereta sendiri.
--
-- Dua sumber konten, keduanya sudah publik:
--   * public.app_releases  -> pengumuman versi baru
--   * public.forum_posts   -> thread forum yang mulai ramai (status='visible',
--                             yang memang sudah bisa dibaca anon lewat RLS)
--
-- Ini SENGAJA hanya memposting ke feed akun sendiri. Tidak ada jalur di sini
-- untuk membalas/berkomentar di thread orang lain — itu spam dan bikin akun
-- kena banned.
--
-- Alurnya: pg_cron (sudah dipakai sejak 20260806120000_vehicle_positions_cron.sql)
-- memanggil trigger_threads_autopost() tiap 15 menit, yang lewat pg_net
-- menembak Edge Function `post-to-threads`. Kredensialnya tidak pernah
-- ditulis di file migrasi — diambil dari Supabase Vault (lihat bagian
-- SETUP di bawah).

create extension if not exists pg_net;

-- ---------------------------------------------------------------------------
-- 1. Token akun sosial
-- ---------------------------------------------------------------------------
-- Long-lived token Threads berumur 60 hari dan bisa (harus) di-refresh
-- sebelum kedaluwarsa. Disimpan di tabel supaya Edge Function bisa menulis
-- balik token hasil refresh — kalau ditaruh di secret env, refresh otomatis
-- tidak mungkin dilakukan tanpa campur tangan manual tiap 2 bulan.
create table public.social_accounts (
  platform text primary key check (platform in ('threads')),
  external_user_id text not null,
  username text,
  access_token text not null,
  token_expires_at timestamptz not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger social_accounts_set_updated_at before update on public.social_accounts
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Catatan apa yang sudah diposting
-- ---------------------------------------------------------------------------
-- Unique (platform, source_table, source_id) adalah pengaman idempotensi:
-- cron jalan tiap 15 menit dan tanpa ini rilis yang sama akan diposting
-- berulang-ulang sampai kena rate limit Threads (250 post / 24 jam).
--
-- `attempts` memisahkan gagal-sementara dari sudah-selesai: baris berstatus
-- 'failed' masih boleh dicoba ulang sampai MAX_ATTEMPTS di Edge Function,
-- sesudah itu didiamkan supaya satu konten rusak tidak menghabiskan kuota.
create table public.social_post_log (
  id uuid primary key default gen_random_uuid(),
  platform text not null,
  source_table text not null check (source_table in ('app_releases', 'forum_posts')),
  source_id text not null,
  external_post_id text,
  status text not null default 'posted' check (status in ('posted', 'failed')),
  attempts integer not null default 1,
  detail text,
  posted_at timestamptz not null default now(),
  unique (platform, source_table, source_id)
);

create index social_post_log_lookup_idx
  on public.social_post_log (platform, source_table, source_id, status);

alter table public.social_accounts enable row level security;
alter table public.social_post_log enable row level security;

-- Sengaja tanpa policy anon/authenticated sama sekali — pola yang sama
-- dipakai admin_users/audit_log di 20260805130000_admin_panel.sql. Khusus
-- social_accounts ini penting: barisnya berisi access token yang setara
-- kredensial login akun Threads, jadi tidak boleh terbaca klien mana pun.
-- `grant` di bawah hanya supaya PostgREST mengizinkan service_role (yang
-- memang sudah melewati RLS) menyentuh tabelnya.
grant select, insert, update, delete on public.social_accounts to service_role;
grant select, insert, update, delete on public.social_post_log to service_role;

comment on table public.social_accounts is
  'Kredensial akun sosial milik Teman Kereta sendiri (saat ini hanya Threads). access_token adalah long-lived token 60 hari yang di-refresh otomatis oleh Edge Function post-to-threads. Service-role only — jangan pernah diberi policy baca untuk anon/authenticated.';

comment on table public.social_post_log is
  'Satu baris per konten yang sudah (atau gagal) diposting ke platform sosial. Unique (platform, source_table, source_id) mencegah post ganda saat cron berjalan ulang.';

-- ---------------------------------------------------------------------------
-- 3. Pemicu terjadwal
-- ---------------------------------------------------------------------------
create or replace function public.trigger_threads_autopost()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  fn_url text;
  svc_key text;
begin
  select decrypted_secret into fn_url
    from vault.decrypted_secrets where name = 'threads_autopost_url';
  select decrypted_secret into svc_key
    from vault.decrypted_secrets where name = 'threads_autopost_key';

  -- Sampai pemilik proyek mengisi Vault (lihat SETUP), cron-nya jalan tapi
  -- tidak melakukan apa-apa. Ini disengaja: migrasi tidak boleh gagal hanya
  -- karena kredensial belum ada.
  if fn_url is null or svc_key is null then
    raise notice 'trigger_threads_autopost: secret Vault belum diisi, dilewati.';
    return;
  end if;

  perform net.http_post(
    url := fn_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || svc_key
    ),
    body := '{}'::jsonb
  );
end;
$$;

revoke all on function public.trigger_threads_autopost() from public, anon, authenticated;

comment on function public.trigger_threads_autopost() is
  'Dipanggil pg_cron tiap 15 menit untuk menembak Edge Function post-to-threads. Membaca URL + service key dari Vault, jadi tidak ada kredensial di file migrasi ini.';

select cron.schedule(
  'threads_autopost',
  '*/15 * * * *',
  $$select public.trigger_threads_autopost();$$
);

-- ---------------------------------------------------------------------------
-- SETUP (dijalankan sekali oleh pemilik proyek, bukan bagian dari migrasi)
-- ---------------------------------------------------------------------------
-- 1) Simpan kredensial pemanggil Edge Function ke Vault:
--
--    select vault.create_secret(
--      'https://<project-ref>.supabase.co/functions/v1/post-to-threads',
--      'threads_autopost_url');
--    select vault.create_secret('<SERVICE_ROLE_KEY>', 'threads_autopost_key');
--
-- 2) Hubungkan akun Threads (sekali saja, token 60 hari lalu auto-refresh):
--
--    node admin/scripts/threads-connect.mjs --token <SHORT_LIVED_TOKEN>
--
-- 3) Set secret Edge Function lalu deploy:
--
--    supabase secrets set PUBLIC_SITE_URL=https://temankereta.web.id
--    supabase functions deploy post-to-threads
--
-- Untuk mematikan sementara tanpa menghapus apa pun:
--    update public.social_accounts set enabled = false where platform = 'threads';

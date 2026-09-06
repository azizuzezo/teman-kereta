-- Balasan otomatis untuk komentar yang masuk di post Threads milik Teman
-- Kereta sendiri — lihat supabase/functions/threads-auto-reply/index.ts.
--
-- Hanya membalas komentar di post kita. Tidak ada jalur di sini untuk
-- berkomentar di thread akun lain.

-- source_table sebelumnya hanya mengenal dua sumber. Komentar yang sudah
-- dibalas perlu dicatat di tabel yang sama supaya satu komentar tidak dibalas
-- berkali-kali tiap cron berjalan.
alter table public.social_post_log
  drop constraint social_post_log_source_table_check;

alter table public.social_post_log
  add constraint social_post_log_source_table_check
  check (source_table in ('app_releases', 'forum_posts', 'threads_replies'));

-- Sengaja default false. Auto-post rilis pernah membanjiri feed pada jalan
-- pertamanya karena langsung aktif begitu di-deploy; fitur yang menulis ke
-- akun publik sebaiknya menunggu keputusan sadar, bukan menyala sendiri.
alter table public.social_accounts
  add column auto_reply_enabled boolean not null default false;

comment on column public.social_accounts.auto_reply_enabled is
  'Saklar balasan otomatis untuk komentar di post sendiri. Default false — nyalakan manual setelah meninjau pola balasannya di threads-auto-reply/index.ts.';

create or replace function public.trigger_threads_auto_reply()
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
    from vault.decrypted_secrets where name = 'threads_autoreply_url';
  select decrypted_secret into svc_key
    from vault.decrypted_secrets where name = 'threads_autopost_key';

  if fn_url is null or svc_key is null then
    raise notice 'trigger_threads_auto_reply: secret Vault belum diisi, dilewati.';
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

revoke all on function public.trigger_threads_auto_reply() from public, anon, authenticated;

-- Setiap 30 menit, bukan 15. Komentar tidak sepenting pengumuman rilis dan
-- balasan yang datang beberapa menit lebih lambat justru terbaca lebih wajar.
select cron.schedule(
  'threads_auto_reply',
  '*/30 * * * *',
  $$select public.trigger_threads_auto_reply();$$
);

-- SETUP (sekali, oleh pemilik proyek):
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1/threads-auto-reply',
--     'threads_autoreply_url');
--
--   supabase functions deploy threads-auto-reply
--
-- Lalu nyalakan setelah meninjau pola balasannya:
--   update public.social_accounts set auto_reply_enabled = true where platform = 'threads';

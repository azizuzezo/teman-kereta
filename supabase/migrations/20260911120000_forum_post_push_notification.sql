-- Push notification ke seluruh pengguna setiap ada postingan Forum baru --
-- pola "Postingan baru dari <nama>" yang sama seperti Instagram/Facebook.
--
-- Postingan forum dibuat langsung dari klien (INSERT langsung ke
-- forum_posts, lihat lib/features/forum/presentation/forum_controller.dart)
-- -- tidak ada endpoint backend yang bisa dipakai untuk memicu push, jadi
-- pemicunya adalah trigger AFTER INSERT + pg_net yang menembak Edge
-- Function send-push-notification yang sudah ada, pola yang sama dengan
-- trigger_threads_autopost() di 20260906090000_threads_auto_post.sql.

create or replace function public.notify_forum_new_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  fn_url text;
  svc_key text;
  author_name text;
  excerpt text;
  recipient_ids uuid[];
begin
  -- Postingan hidden/removed (mis. langsung dihapus pemiliknya) tidak perlu
  -- diberitahukan ke siapa pun.
  if new.status <> 'visible' then
    return new;
  end if;

  select decrypted_secret into fn_url
    from vault.decrypted_secrets where name = 'forum_post_push_url';
  select decrypted_secret into svc_key
    from vault.decrypted_secrets where name = 'forum_post_push_key';

  -- Sampai pemilik proyek mengisi Vault (lihat SETUP), trigger jalan tapi
  -- tidak melakukan apa-apa -- migrasi tidak boleh gagal hanya karena
  -- kredensial belum ada.
  if fn_url is null or svc_key is null then
    raise notice 'notify_forum_new_post: secret Vault belum diisi, dilewati.';
    return new;
  end if;

  select coalesce(display_name, 'Pengguna Teman Kereta') into author_name
    from public.users where id = new.user_id;

  excerpt := left(new.body, 100);
  if char_length(new.body) > 100 then
    excerpt := excerpt || '...';
  end if;

  -- Seluruh pengguna lain yang punya device token terdaftar -- penulis
  -- sendiri dikecualikan, sama seperti Instagram/Facebook tidak mengirim
  -- notifikasi "postingan baru" ke pemilik postingan itu sendiri.
  select array_agg(distinct user_id) into recipient_ids
    from public.device_tokens
    where user_id <> new.user_id;

  if recipient_ids is null or array_length(recipient_ids, 1) is null then
    return new;
  end if;

  perform net.http_post(
    url := fn_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || svc_key
    ),
    body := jsonb_build_object(
      'user_ids', to_jsonb(recipient_ids),
      'title', 'Postingan baru dari ' || author_name,
      'body', excerpt
    )
  );

  return new;
end;
$$;

revoke all on function public.notify_forum_new_post() from public, anon, authenticated;

create trigger forum_posts_notify_new_post
  after insert on public.forum_posts
  for each row execute function public.notify_forum_new_post();

comment on function public.notify_forum_new_post() is
  'Dipicu tiap ada baris baru di forum_posts (status visible): menembak Edge Function send-push-notification lewat pg_net supaya seluruh pengguna lain dapat push "Postingan baru dari ...", mirip notifikasi postingan baru di Instagram/Facebook. URL + service key diambil dari Vault (lihat SETUP).';

-- ---------------------------------------------------------------------------
-- SETUP (dijalankan sekali oleh pemilik proyek, bukan bagian dari migrasi)
-- ---------------------------------------------------------------------------
-- 1) Simpan kredensial pemanggil Edge Function ke Vault:
--
--    select vault.create_secret(
--      'https://<project-ref>.supabase.co/functions/v1/send-push-notification',
--      'forum_post_push_url');
--    select vault.create_secret('<SERVICE_ROLE_KEY>', 'forum_post_push_key');
--
-- 2) Pastikan Edge Function send-push-notification sudah di-deploy dan
--    secret-nya (FIREBASE_PROJECT_ID, FIREBASE_SERVICE_ACCOUNT_JSON) sudah
--    diisi -- lihat supabase/functions/send-push-notification/index.ts.
--
-- Untuk mematikan sementara tanpa menghapus apa pun:
--    drop trigger forum_posts_notify_new_post on public.forum_posts;

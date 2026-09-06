// Memposting otomatis ke akun Threads (Meta) milik Teman Kereta sendiri.
//
// Dipanggil pg_cron tiap 15 menit lewat public.trigger_threads_autopost()
// — lihat supabase/migrations/20260906090000_threads_auto_post.sql. Bisa juga
// dipanggil manual dengan service role key untuk uji coba.
//
// Yang diposting (keduanya konten yang memang sudah publik):
//   * forum_posts   -> OTOMATIS. Thread visible yang sudah melewati ambang
//                      like, dengan kutipan pendek + tautan balik ke forum.
//                      Bukan menyalin utuh isi tulisan orang.
//   * app_releases  -> HANYA SAAT DIMINTA. Pemilik proyek memegang kendali
//                      kapan pengumuman versi naik ke akun publiknya, jadi
//                      cron TIDAK PERNAH mengumumkan rilis dengan sendirinya.
//                      Harus dipicu manual dengan body {"include_releases":true}
//                      (atau {"release_id":"<uuid>"} untuk satu versi tertentu).
//
// Yang TIDAK dilakukan: membalas atau berkomentar di thread akun lain. Fungsi
// ini hanya bisa menulis ke feed akun sendiri.
//
// Auth: service role key, sama seperti send-push-notification — bukan endpoint
// untuk pengguna akhir.
//
// Deploy (dijalankan pemilik proyek):
//   supabase functions deploy post-to-threads
//   supabase secrets set PUBLIC_SITE_URL=https://temankereta.web.id
//
// THREADS_APP_SECRET tidak dibutuhkan di sini — client secret hanya dipakai
// saat menukar token pertama kali (admin/scripts/threads-connect.mjs).
// Endpoint refresh Threads cukup dengan token lamanya.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PUBLIC_SITE_URL = Deno.env.get("PUBLIC_SITE_URL") ??
  "https://temankereta.web.id";

const THREADS_API = "https://graph.threads.net/v1.0";
const THREADS_OAUTH = "https://graph.threads.net";

// Threads memberi 500 karakter per post. Disisakan sedikit ruang supaya
// penambahan tautan di akhir tidak pernah memotong kalimat di tengah.
const MAX_POST_CHARS = 480;

// Berapa banyak yang boleh diposting dalam satu kali jalan. Cron tiap 15
// menit x 2 post = maksimal 192/hari, masih di bawah plafon Threads (250 post
// per 24 jam) bahkan kalau forum sedang sangat ramai.
const MAX_POSTS_PER_RUN = 2;

// Ambang supaya yang naik ke Threads hanya thread yang memang menarik, bukan
// tiap celetukan. Angkanya sengaja konservatif — naikkan kalau forum makin ramai.
const FORUM_MIN_LIKES = 5;
const FORUM_MAX_AGE_HOURS = 48;

// Batas umur rilis yang masih layak diumumkan. TANPA ini, jalan pertama
// menganggap seluruh riwayat app_releases sebagai "belum diposting" dan
// membanjiri feed dengan pengumuman versi lama — persis yang terjadi saat
// fitur ini pertama dinyalakan (5 pengumuman versi lama terlanjur naik).
// Rilis yang lebih tua dari ini dilewati diam-diam dan dicatat sebagai
// sudah ditangani, jadi kejadian itu tidak bisa terulang.
const RELEASE_MAX_AGE_HOURS = 72;

// Sesudah 3 kali gagal, satu konten didiamkan. Tanpa ini, satu baris rusak
// akan dicoba ulang tiap 15 menit selamanya dan menghabiskan kuota harian.
const MAX_ATTEMPTS = 3;

// Token 60 hari di-refresh saat sisanya tinggal 10 hari. Threads mensyaratkan
// token berumur minimal 24 jam sebelum boleh di-refresh, jadi jendela selebar
// ini aman sekalipun cron sempat mati beberapa hari.
const REFRESH_WHEN_DAYS_LEFT = 10;

interface SocialAccount {
  platform: string;
  external_user_id: string;
  access_token: string;
  token_expires_at: string;
  enabled: boolean;
}

interface Candidate {
  sourceTable: "app_releases" | "forum_posts";
  sourceId: string;
  text: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Cron mengirim body kosong, jadi defaultnya selalu "jangan umumkan
    // rilis". Pengumuman versi hanya naik kalau ada yang memintanya secara
    // eksplisit lewat body permintaan.
    const options = (await req.json().catch(() => ({}))) as {
      include_releases?: boolean;
      release_id?: string;
    };

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: account, error: accountError } = await admin
      .from("social_accounts")
      .select("platform, external_user_id, access_token, token_expires_at, enabled")
      .eq("platform", "threads")
      .maybeSingle<SocialAccount>();

    if (accountError) {
      return json({ error: `Gagal membaca social_accounts: ${accountError.message}` }, 500);
    }
    if (!account) {
      return json({
        error:
          "Akun Threads belum terhubung. Jalankan: node admin/scripts/threads-connect.mjs --token <SHORT_LIVED_TOKEN>",
      }, 412);
    }
    if (!account.enabled) {
      return json({ skipped: "Auto-post Threads sedang dimatikan (enabled=false)." });
    }

    const token = await ensureFreshToken(admin, account);
    const candidates = await collectCandidates(admin, options);

    if (candidates.length === 0) {
      return json({ posted: 0, note: "Tidak ada konten baru yang layak diposting." });
    }

    const results: unknown[] = [];

    for (const candidate of candidates.slice(0, MAX_POSTS_PER_RUN)) {
      try {
        const externalId = await publishToThreads(
          account.external_user_id,
          token,
          candidate.text,
        );
        await recordResult(admin, candidate, "posted", externalId, null);
        results.push({ ...candidate, status: "posted", external_post_id: externalId });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        await recordResult(admin, candidate, "failed", null, message);
        results.push({ ...candidate, status: "failed", error: message });
      }
    }

    return json({ posted: results.length, results });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});

// ---------------------------------------------------------------------------
// Token
// ---------------------------------------------------------------------------

// Long-lived token Threads hanya berumur 60 hari. Kalau tidak pernah
// di-refresh, auto-post akan mati diam-diam dua bulan setelah dipasang —
// makanya refresh dijalankan sebagai bagian dari tiap kali jalan, bukan
// tugas manual yang gampang terlupa.
async function ensureFreshToken(
  admin: ReturnType<typeof createClient>,
  account: SocialAccount,
): Promise<string> {
  const expiresAt = new Date(account.token_expires_at).getTime();
  const daysLeft = (expiresAt - Date.now()) / 86_400_000;

  if (daysLeft > REFRESH_WHEN_DAYS_LEFT) return account.access_token;

  if (daysLeft <= 0) {
    throw new Error(
      "Token Threads sudah kedaluwarsa dan tidak bisa di-refresh. Hubungkan ulang dengan admin/scripts/threads-connect.mjs.",
    );
  }

  const url = new URL(`${THREADS_OAUTH}/refresh_access_token`);
  url.searchParams.set("grant_type", "th_refresh_token");
  url.searchParams.set("access_token", account.access_token);

  const res = await fetch(url);
  const payload = await res.json().catch(() => ({}));

  if (!res.ok || !payload.access_token) {
    // Token lama masih berlaku beberapa hari lagi, jadi kegagalan refresh
    // bukan alasan untuk membatalkan post kali ini — cukup dicoba lagi
    // pada jalan berikutnya.
    console.error("Refresh token Threads gagal:", JSON.stringify(payload));
    return account.access_token;
  }

  const newExpiry = new Date(
    Date.now() + Number(payload.expires_in ?? 5_184_000) * 1000,
  ).toISOString();

  await admin
    .from("social_accounts")
    .update({ access_token: payload.access_token, token_expires_at: newExpiry })
    .eq("platform", "threads");

  return payload.access_token as string;
}

// ---------------------------------------------------------------------------
// Pemilihan konten
// ---------------------------------------------------------------------------

async function collectCandidates(
  admin: ReturnType<typeof createClient>,
  options: { include_releases?: boolean; release_id?: string },
): Promise<Candidate[]> {
  const wantReleases = options.include_releases === true ||
    typeof options.release_id === "string";

  // Rilis didahulukan daripada thread forum: pengumuman versi baru lebih
  // cepat basi, sementara thread ramai tetap relevan beberapa jam kemudian.
  const releaseSince = new Date(
    Date.now() - RELEASE_MAX_AGE_HOURS * 3_600_000,
  ).toISOString();

  // Bentuk barisnya sama dengan yang diterima composeReleaseText di bawah,
  // yang juga sudah memakai any — konsisten dengan gaya berkas ini.
  // deno-lint-ignore no-explicit-any
  let releases: any[] | null = null;

  if (wantReleases) {
    let query = admin
      .from("app_releases")
      .select("id, version_name, changelog, apk_url, published_at");

    // Saat satu versi disebut namanya, batas umur tidak berlaku — pemilik
    // proyek jelas tahu apa yang sedang diumumkannya.
    query = options.release_id
      ? query.eq("id", options.release_id)
      : query.gte("published_at", releaseSince);

    const { data } = await query
      .order("version_code", { ascending: false })
      .limit(5);
    releases = data;
  }

  const since = new Date(Date.now() - FORUM_MAX_AGE_HOURS * 3_600_000)
    .toISOString();

  const { data: posts } = await admin
    .from("forum_posts")
    .select("id, body, like_count, comment_count, created_at, status, lines(name)")
    .eq("status", "visible")
    .gte("created_at", since)
    .gte("like_count", FORUM_MIN_LIKES)
    .order("like_count", { ascending: false })
    .limit(10);

  // Riwayat semua kandidat diambil sekali, bukan satu query per kandidat.
  const handled = await loadHandled(
    admin,
    (releases ?? []).map((r) => r.id),
    (posts ?? []).map((p) => p.id),
  );

  const candidates: Candidate[] = [];

  for (const release of releases ?? []) {
    if (handled.has(`app_releases:${release.id}`)) continue;
    candidates.push({
      sourceTable: "app_releases",
      sourceId: release.id,
      text: composeReleaseText(release),
    });
  }

  for (const post of posts ?? []) {
    if (handled.has(`forum_posts:${post.id}`)) continue;
    // Thread yang isinya menempelkan tautan keluar dilewati — memantulkan
    // tautan orang lain lewat akun resmi itu risiko yang tidak perlu diambil.
    if (/https?:\/\//i.test(post.body)) continue;
    candidates.push({
      sourceTable: "forum_posts",
      sourceId: post.id,
      text: composeForumText(post),
    });
  }

  return candidates;
}

// Mengembalikan kunci "<source_table>:<id>" untuk konten yang tidak boleh
// diposting lagi: entah sudah berhasil, atau sudah gagal MAX_ATTEMPTS kali.
async function loadHandled(
  admin: ReturnType<typeof createClient>,
  releaseIds: string[],
  postIds: string[],
): Promise<Set<string>> {
  const ids = [...releaseIds, ...postIds];
  if (ids.length === 0) return new Set();

  const { data } = await admin
    .from("social_post_log")
    .select("source_table, source_id, status, attempts")
    .eq("platform", "threads")
    .in("source_id", ids);

  const handled = new Set<string>();
  for (const row of data ?? []) {
    if (row.status === "posted" || row.attempts >= MAX_ATTEMPTS) {
      handled.add(`${row.source_table}:${row.source_id}`);
    }
  }
  return handled;
}

// deno-lint-ignore no-explicit-any
function composeReleaseText(release: any): string {
  const lines = [`🚆 Teman Kereta ${release.version_name} sudah rilis.`];

  if (release.changelog?.trim()) {
    lines.push("", truncate(release.changelog.trim(), 260));
  }

  lines.push("", `Unduh: ${PUBLIC_SITE_URL}`);
  return truncate(lines.join("\n"), MAX_POST_CHARS);
}

// deno-lint-ignore no-explicit-any
function composeForumText(post: any): string {
  // PostgREST mengembalikan relasi many-to-one sebagai objek, tapi versi
  // lama membungkusnya dalam array — ditangani keduanya supaya nama jalur
  // tidak diam-diam hilang dari post.
  const relation = Array.isArray(post.lines) ? post.lines[0] : post.lines;
  const lineName = relation?.name ? `[${relation.name}] ` : "";
  const link = `${PUBLIC_SITE_URL}/forum?post=${post.id}`;

  // Kutipan pendek, bukan salinan utuh — supaya orang datang ke forumnya
  // untuk membaca lengkap, dan tulisan penggunanya tidak dipindah bulat-bulat
  // ke platform lain.
  const excerpt = truncate(post.body.replace(/\s+/g, " ").trim(), 180);

  return truncate(
    [
      `${lineName}Lagi ramai di forum Teman Kereta:`,
      "",
      `"${excerpt}"`,
      "",
      `💬 ${post.comment_count} komentar · Baca & ikut bahas: ${link}`,
    ].join("\n"),
    MAX_POST_CHARS,
  );
}

function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  return `${text.slice(0, max - 1).trimEnd()}…`;
}

// ---------------------------------------------------------------------------
// Threads API
// ---------------------------------------------------------------------------

// Threads memakai model dua langkah: bikin "container" dulu, baru
// dipublikasikan. Meta menyarankan jeda sebelum publish — untuk post teks
// biasanya siap seketika, tapi jeda pendek ini menghindari container yang
// sesekali belum selesai diproses.
async function publishToThreads(
  userId: string,
  token: string,
  text: string,
): Promise<string> {
  const createUrl = new URL(`${THREADS_API}/${userId}/threads`);
  createUrl.searchParams.set("media_type", "TEXT");
  createUrl.searchParams.set("text", text);
  createUrl.searchParams.set("access_token", token);

  const createRes = await fetch(createUrl, { method: "POST" });
  const created = await createRes.json().catch(() => ({}));

  if (!createRes.ok || !created.id) {
    throw new Error(
      `Gagal membuat container Threads: ${JSON.stringify(created)}`,
    );
  }

  await new Promise((resolve) => setTimeout(resolve, 3000));

  const publishUrl = new URL(`${THREADS_API}/${userId}/threads_publish`);
  publishUrl.searchParams.set("creation_id", created.id);
  publishUrl.searchParams.set("access_token", token);

  const publishRes = await fetch(publishUrl, { method: "POST" });
  const published = await publishRes.json().catch(() => ({}));

  if (!publishRes.ok || !published.id) {
    throw new Error(`Gagal publish ke Threads: ${JSON.stringify(published)}`);
  }

  return published.id as string;
}

// ---------------------------------------------------------------------------
// Pencatatan
// ---------------------------------------------------------------------------

async function recordResult(
  admin: ReturnType<typeof createClient>,
  candidate: Candidate,
  status: "posted" | "failed",
  externalId: string | null,
  detail: string | null,
): Promise<void> {
  const { data: existing } = await admin
    .from("social_post_log")
    .select("attempts")
    .eq("platform", "threads")
    .eq("source_table", candidate.sourceTable)
    .eq("source_id", candidate.sourceId)
    .maybeSingle();

  await admin.from("social_post_log").upsert({
    platform: "threads",
    source_table: candidate.sourceTable,
    source_id: candidate.sourceId,
    external_post_id: externalId,
    status,
    attempts: (existing?.attempts ?? 0) + 1,
    detail: detail ? truncate(detail, 500) : null,
    posted_at: new Date().toISOString(),
  }, { onConflict: "platform,source_table,source_id" });
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

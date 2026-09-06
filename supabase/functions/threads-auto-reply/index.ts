// Membalas komentar yang masuk di post Threads milik Teman Kereta sendiri.
//
// Batas tegasnya: fungsi ini hanya membaca balasan pada media milik akun kita
// (`GET /{user-id}/threads` lalu `GET /{media-id}/replies`). Tidak ada jalur
// untuk mencari atau berkomentar di thread akun lain — itu spam, melanggar
// ToS Threads, dan berujung akun dibanned.
//
// Sengaja TIDAK membalas semua komentar. Balasan kalengan ke setiap orang
// terbaca seperti bot dan merusak kesan akunnya; yang dibalas hanya komentar
// yang jelas berupa pertanyaan yang jawabannya memang sudah pasti (di mana
// unduhnya, apakah ada versi iOS, apakah berbayar). Sisanya dibiarkan untuk
// dijawab manusia.
//
// Dipanggil pg_cron tiap 30 menit lewat public.trigger_threads_auto_reply()
// — lihat supabase/migrations/20260906120000_threads_auto_reply.sql.
//
// Deploy:
//   supabase functions deploy threads-auto-reply
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PUBLIC_SITE_URL = Deno.env.get("PUBLIC_SITE_URL") ??
  "https://temankereta.web.id";

const THREADS_API = "https://graph.threads.net/v1.0";

// Berapa post terakhir yang kolom komentarnya diperiksa tiap kali jalan.
const RECENT_POSTS_TO_SCAN = 10;

// Balasan per jalan dibatasi supaya satu lonjakan komentar tidak menghabiskan
// plafon Threads (1.000 balasan / 24 jam) dan tidak terlihat seperti banjir.
const MAX_REPLIES_PER_RUN = 5;

// Komentar yang lebih tua dari ini dilewati. Membalas komentar seminggu lalu
// terbaca aneh, dan pada jalan pertama ini mencegah seluruh riwayat komentar
// ikut dibalas sekaligus — persis kesalahan yang pernah terjadi saat auto-post
// rilis pertama dinyalakan.
const COMMENT_MAX_AGE_HOURS = 48;

interface ReplyRule {
  key: string;
  test: RegExp;
  reply: string;
}

// Urutannya berarti: aturan pertama yang cocok dipakai. Yang lebih spesifik
// diletakkan di atas.
const RULES: ReplyRule[] = [
  {
    key: "ios",
    test: /\b(ios|iphone|ipad|app ?store)\b/i,
    reply:
      `Untuk sekarang Teman Kereta baru tersedia di Android. Versi iOS belum ada — kabar terbarunya akan diumumkan di sini. 🙏`,
  },
  {
    key: "harga",
    test: /\b(bayar|berbayar|harga|gratis|langganan|premium|biaya)\b/i,
    reply:
      `Teman Kereta gratis sepenuhnya, tanpa iklan dan tanpa langganan. Unduh di ${PUBLIC_SITE_URL} 🚆`,
  },
  {
    key: "unduh",
    test:
      /\b(link|tautan|unduh|download|dl|apk|di ?mana|dimana|gimana ?cara|cara ?(pakai|install|instal|pasang))\b/i,
    reply: `Bisa diunduh langsung di ${PUBLIC_SITE_URL} — gratis. 🚆`,
  },
];

interface SocialAccount {
  external_user_id: string;
  username: string | null;
  access_token: string;
  token_expires_at: string;
  enabled: boolean;
  auto_reply_enabled: boolean;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: account } = await admin
      .from("social_accounts")
      .select(
        "external_user_id, username, access_token, token_expires_at, enabled, auto_reply_enabled",
      )
      .eq("platform", "threads")
      .maybeSingle<SocialAccount>();

    if (!account) return json({ error: "Akun Threads belum terhubung." }, 412);
    if (!account.enabled || !account.auto_reply_enabled) {
      return json({
        skipped:
          "Balasan otomatis mati. Nyalakan dengan: update public.social_accounts set auto_reply_enabled = true where platform = 'threads';",
      });
    }
    if (new Date(account.token_expires_at).getTime() <= Date.now()) {
      return json({ error: "Token Threads sudah kedaluwarsa." }, 412);
    }

    const token = account.access_token;
    const candidates = await collectComments(admin, account, token);

    const results: unknown[] = [];

    for (const c of candidates.slice(0, MAX_REPLIES_PER_RUN)) {
      try {
        const replyId = await publishReply(
          account.external_user_id,
          token,
          c.reply,
          c.commentId,
        );
        await logReply(admin, c.commentId, replyId, c.ruleKey, null);
        results.push({ comment_id: c.commentId, rule: c.ruleKey, status: "replied" });
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        await logReply(admin, c.commentId, null, c.ruleKey, message);
        results.push({ comment_id: c.commentId, status: "failed", error: message });
      }
    }

    return json({ replied: results.length, results });
  } catch (err) {
    return json({ error: err instanceof Error ? err.message : String(err) }, 500);
  }
});

interface CommentCandidate {
  commentId: string;
  ruleKey: string;
  reply: string;
}

async function collectComments(
  admin: ReturnType<typeof createClient>,
  account: SocialAccount,
  token: string,
): Promise<CommentCandidate[]> {
  const posts = await fetchJson(
    `${THREADS_API}/${account.external_user_id}/threads?fields=id&limit=${RECENT_POSTS_TO_SCAN}&access_token=${token}`,
  );

  const since = Date.now() - COMMENT_MAX_AGE_HOURS * 3_600_000;
  const found: CommentCandidate[] = [];
  const seenIds: string[] = [];

  for (const post of posts?.data ?? []) {
    const replies = await fetchJson(
      `${THREADS_API}/${post.id}/replies?fields=id,text,username,timestamp&access_token=${token}`,
    );

    for (const reply of replies?.data ?? []) {
      // Membalas balasan sendiri akan membuat percakapan berputar tanpa henti.
      if (
        account.username &&
        reply.username?.toLowerCase() === account.username.toLowerCase()
      ) {
        continue;
      }

      if (!reply.text) continue;
      if (reply.timestamp && new Date(reply.timestamp).getTime() < since) continue;

      const rule = RULES.find((r) => r.test.test(reply.text));
      if (!rule) continue; // Bukan pertanyaan yang punya jawaban pasti — biarkan.

      seenIds.push(reply.id);
      found.push({ commentId: reply.id, ruleKey: rule.key, reply: rule.reply });
    }
  }

  if (seenIds.length === 0) return [];

  // Satu kali baca untuk semua kandidat, bukan satu query per komentar.
  const { data: handled } = await admin
    .from("social_post_log")
    .select("source_id")
    .eq("platform", "threads")
    .eq("source_table", "threads_replies")
    .in("source_id", seenIds);

  const already = new Set((handled ?? []).map((h) => h.source_id));
  return found.filter((c) => !already.has(c.commentId));
}

async function publishReply(
  userId: string,
  token: string,
  text: string,
  replyToId: string,
): Promise<string> {
  const createUrl = new URL(`${THREADS_API}/${userId}/threads`);
  createUrl.searchParams.set("media_type", "TEXT");
  createUrl.searchParams.set("text", text);
  createUrl.searchParams.set("reply_to_id", replyToId);
  createUrl.searchParams.set("access_token", token);

  const created = await postJson(createUrl);
  if (!created?.id) {
    throw new Error(`Gagal membuat container balasan: ${JSON.stringify(created)}`);
  }

  await new Promise((r) => setTimeout(r, 3000));

  const publishUrl = new URL(`${THREADS_API}/${userId}/threads_publish`);
  publishUrl.searchParams.set("creation_id", created.id);
  publishUrl.searchParams.set("access_token", token);

  const published = await postJson(publishUrl);
  if (!published?.id) {
    throw new Error(`Gagal publish balasan: ${JSON.stringify(published)}`);
  }

  return published.id as string;
}

// Dicatat baik saat berhasil maupun gagal: tanpa ini, komentar yang selalu
// gagal dibalas akan dicoba ulang tiap 30 menit selamanya.
async function logReply(
  admin: ReturnType<typeof createClient>,
  commentId: string,
  replyId: string | null,
  ruleKey: string,
  error: string | null,
): Promise<void> {
  await admin.from("social_post_log").upsert({
    platform: "threads",
    source_table: "threads_replies",
    source_id: commentId,
    external_post_id: replyId,
    status: error ? "failed" : "posted",
    attempts: 1,
    detail: error ? error.slice(0, 500) : `aturan: ${ruleKey}`,
    posted_at: new Date().toISOString(),
  }, { onConflict: "platform,source_table,source_id" });
}

// deno-lint-ignore no-explicit-any
async function fetchJson(url: string): Promise<any> {
  const res = await fetch(url);
  return await res.json().catch(() => null);
}

// deno-lint-ignore no-explicit-any
async function postJson(url: URL): Promise<any> {
  const res = await fetch(url, { method: "POST" });
  return await res.json().catch(() => null);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

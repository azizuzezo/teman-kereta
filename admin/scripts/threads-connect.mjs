// Menghubungkan akun Threads (Meta) milik Teman Kereta ke auto-post.
// Dijalankan SEKALI; sesudah itu Edge Function post-to-threads yang
// memperpanjang tokennya sendiri tiap kali mau kedaluwarsa.
//
// Alur lengkapnya tiga langkah, semuanya lewat script ini:
//
//   1. node scripts/threads-connect.mjs --url
//        Mencetak URL otorisasi. Buka di browser, login sebagai akun Threads
//        Teman Kereta, setujui izinnya. Browser lalu dilempar ke redirect URI
//        sambil membawa ?code=...
//
//   2. node scripts/threads-connect.mjs --code <CODE>
//        Menukar code -> short-lived token (1 jam) -> long-lived token
//        (60 hari), membaca id + username akun, lalu menyimpannya ke
//        public.social_accounts.
//
//   3. Selesai. Tidak perlu menjalankan script ini lagi kecuali tokennya
//      sempat mati total (lebih dari 60 hari cron tidak jalan).
//
// JALAN PINTAS (lebih disarankan kalau tersedia): dashboard Meta punya panel
// "Generator Token Pengguna" di Kasus penggunaan -> Akses Threads API ->
// Pengaturan, yang bisa langsung mengeluarkan token 60 hari untuk akun
// penguji. Kalau pakai itu, seluruh alur OAuth di atas tidak perlu:
//
//   node scripts/threads-connect.mjs --long-token <TOKEN_60_HARI>
//
// Kalau kamu punya short-lived token dari tempat lain, langkah 1-2 juga bisa
// dilewati: node scripts/threads-connect.mjs --token <SHORT_LIVED_TOKEN>
//
// Prasyarat di https://developers.facebook.com (app kamu -> Threads API):
//   - Izin: threads_basic + threads_content_publish
//   - Redirect callback URL didaftarkan PERSIS sama dengan REDIRECT_URI di
//     bawah (beda satu garis miring pun ditolak Meta).
//   - Akun Threads-mu ditambahkan sebagai Threads Tester, dan undangannya
//     sudah diterima dari aplikasi Threads (Settings -> Website permissions).
//
// Reads admin/.env.local itself, same as bootstrap-admin.mjs — no dotenv
// dependency. Butuh THREADS_APP_ID dan THREADS_APP_SECRET di sana.
import { readFileSync } from "node:fs";
import { createClient } from "@supabase/supabase-js";

const THREADS_AUTHORIZE = "https://threads.net/oauth/authorize";
const THREADS_OAUTH = "https://graph.threads.net";
const THREADS_API = "https://graph.threads.net/v1.0";

// Halaman statis di landing page yang tugasnya cuma menampilkan `code` agar
// gampang disalin — lihat landing_page/threads-callback/index.html. Nilainya
// harus sama persis dengan yang didaftarkan di dashboard Meta.
const REDIRECT_URI = "https://temankereta.web.id/threads-callback";

const SCOPES = "threads_basic,threads_content_publish";

function loadEnvLocal() {
  const text = readFileSync(new URL("../.env.local", import.meta.url), "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    env[trimmed.slice(0, eq)] = trimmed.slice(eq + 1);
  }
  return env;
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (!argv[i].startsWith("--")) continue;
    const key = argv[i].slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith("--")) {
      args[key] = true;
    } else {
      args[key] = next;
      i += 1;
    }
  }
  return args;
}

function printAuthorizeUrl(appId) {
  const url = new URL(THREADS_AUTHORIZE);
  url.searchParams.set("client_id", appId);
  url.searchParams.set("redirect_uri", REDIRECT_URI);
  url.searchParams.set("scope", SCOPES);
  url.searchParams.set("response_type", "code");

  console.log(
    [
      "Buka URL ini di browser, login sebagai akun Threads Teman Kereta,",
      "lalu setujui izinnya:",
      "",
      url.toString(),
      "",
      `Sesudah disetujui kamu akan dilempar ke ${REDIRECT_URI}?code=...`,
      "Salin nilai code-nya, lalu jalankan:",
      "",
      "  node scripts/threads-connect.mjs --code <CODE>",
    ].join("\n"),
  );
}

// Menukar authorization code jadi short-lived token (berlaku 1 jam).
async function exchangeCodeForShortToken(appId, appSecret, code) {
  // Meta kerap menempelkan '#_' di ujung code saat redirect di browser.
  // Kalau ikut terkirim, tukarannya ditolak dengan pesan yang membingungkan.
  const cleanCode = code.replace(/#_$/, "").trim();

  const body = new URLSearchParams({
    client_id: appId,
    client_secret: appSecret,
    grant_type: "authorization_code",
    redirect_uri: REDIRECT_URI,
    code: cleanCode,
  });

  const res = await fetch(`${THREADS_OAUTH}/oauth/access_token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const payload = await res.json().catch(() => ({}));

  if (!res.ok || !payload.access_token) {
    console.error(
      "Gagal menukar code jadi token:",
      JSON.stringify(payload, null, 2),
    );
    console.error(
      "\nPenyebab paling sering: code sudah dipakai (sekali pakai saja, ambil\n" +
        `code baru lewat --url), atau redirect URI di dashboard Meta tidak persis\n"${REDIRECT_URI}".`,
    );
    process.exit(1);
  }

  return payload.access_token;
}

// Menukar short-lived jadi long-lived token (berlaku 60 hari).
async function exchangeForLongToken(appSecret, shortToken) {
  const url = new URL(`${THREADS_OAUTH}/access_token`);
  url.searchParams.set("grant_type", "th_exchange_token");
  url.searchParams.set("client_secret", appSecret);
  url.searchParams.set("access_token", shortToken);

  const res = await fetch(url);
  const payload = await res.json().catch(() => ({}));

  if (!res.ok || !payload.access_token) {
    console.error(
      "Gagal menukar jadi long-lived token:",
      JSON.stringify(payload, null, 2),
    );
    process.exit(1);
  }

  return {
    token: payload.access_token,
    expiresAt: new Date(
      Date.now() + Number(payload.expires_in ?? 5_184_000) * 1000,
    ),
  };
}

async function fetchAccount(token) {
  const url = new URL(`${THREADS_API}/me`);
  url.searchParams.set("fields", "id,username");
  url.searchParams.set("access_token", token);

  const res = await fetch(url);
  const payload = await res.json().catch(() => ({}));

  if (!res.ok || !payload.id) {
    console.error("Gagal membaca /me:", JSON.stringify(payload, null, 2));
    process.exit(1);
  }

  return payload;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const env = loadEnvLocal();

  const appId = args["app-id"] ?? env.THREADS_APP_ID;
  const appSecret = args["app-secret"] ?? env.THREADS_APP_SECRET;

  if (!appId || !appSecret) {
    console.error(
      "THREADS_APP_ID / THREADS_APP_SECRET tidak ketemu.\n" +
        "Tambahkan keduanya ke admin/.env.local, atau pakai --app-id / --app-secret.",
    );
    process.exit(1);
  }

  // Mode 1: cuma cetak URL otorisasi, tidak menyentuh apa pun.
  if (args.url || (!args.code && !args.token && !args["long-token"])) {
    printAuthorizeUrl(appId);
    return;
  }

  if (!env.NEXT_PUBLIC_SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    console.error(
      "NEXT_PUBLIC_SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY tidak ada di admin/.env.local.",
    );
    process.exit(1);
  }

  // Mode 2: token dari "Generator Token Pengguna" sudah berumur 60 hari, jadi
  // tidak boleh ditukar lagi — endpoint th_exchange_token hanya menerima
  // short-lived token dan akan menolak token yang sudah panjang.
  let longToken;
  let expiresAt;

  if (args["long-token"]) {
    longToken = String(args["long-token"]);
    // Dashboard tidak memberitahu sisa umur persisnya. 60 hari adalah masa
    // berlaku baku Threads, dan kalaupun meleset beberapa hari, Edge Function
    // sudah memperpanjang saat sisanya tinggal 10 hari.
    expiresAt = new Date(Date.now() + 5_184_000 * 1000);
  } else {
    const shortToken = args.code
      ? await exchangeCodeForShortToken(appId, appSecret, String(args.code))
      : String(args.token);
    ({ token: longToken, expiresAt } = await exchangeForLongToken(
      appSecret,
      shortToken,
    ));
  }

  const me = await fetchAccount(longToken);

  const supabase = createClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.SUPABASE_SERVICE_ROLE_KEY,
  );

  const { error } = await supabase.from("social_accounts").upsert({
    platform: "threads",
    external_user_id: me.id,
    username: me.username ?? null,
    access_token: longToken,
    token_expires_at: expiresAt.toISOString(),
    enabled: true,
  }, { onConflict: "platform" });

  if (error) {
    console.error("Gagal menyimpan ke social_accounts:", error.message);
    process.exit(1);
  }

  console.log(
    [
      `Akun Threads @${me.username ?? me.id} terhubung.`,
      `Token berlaku sampai ${expiresAt.toISOString()}.`,
      "",
      "Sesudah ini Edge Function post-to-threads memperpanjang tokennya",
      "sendiri, jadi script ini tidak perlu dijalankan lagi.",
      "",
      "Uji sekali tanpa menunggu cron:",
      "  curl -X POST '<SUPABASE_URL>/functions/v1/post-to-threads' \\",
      "    -H 'Authorization: Bearer <SERVICE_ROLE_KEY>'",
    ].join("\n"),
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

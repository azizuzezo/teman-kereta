// Dua webhook yang diwajibkan Meta saat mendaftarkan app Threads:
//
//   POST .../threads-callbacks/deauthorize
//        Dipanggil saat seseorang mencabut izin app ini.
//
//   POST .../threads-callbacks/data-deletion
//        Dipanggil saat seseorang meminta datanya dihapus. Meta mewajibkan
//        balasannya berupa JSON {url, confirmation_code} — kalau formatnya
//        meleset, pendaftaran URL-nya ditolak.
//
// Konteksnya penting: app ini hanya pernah mengotorisasi SATU akun, yaitu
// akun Threads milik Teman Kereta sendiri. Tidak ada data Threads pengguna
// lain yang disimpan di mana pun. Jadi satu-satunya "penghapusan data" yang
// masuk akal adalah membuang baris token di public.social_accounts, yang
// sekaligus menghentikan auto-post.
//
// Auth: tidak pakai JWT Supabase — Meta tidak mengirim header Authorization.
// Keasliannya dibuktikan lewat signed_request yang ditandatangani HMAC-SHA256
// dengan app secret, diverifikasi di readSignedRequest() di bawah. Karena
// itu fungsi ini didaftarkan verify_jwt = false di supabase/config.toml.
//
// Deploy:
//   supabase secrets set THREADS_APP_SECRET=...
//   supabase secrets set PUBLIC_SITE_URL=https://temankereta.web.id
//   supabase functions deploy threads-callbacks --no-verify-jwt
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const THREADS_APP_SECRET = Deno.env.get("THREADS_APP_SECRET")!;
const PUBLIC_SITE_URL = Deno.env.get("PUBLIC_SITE_URL") ??
  "https://temankereta.web.id";

interface SignedPayload {
  user_id?: string;
  algorithm?: string;
  issued_at?: number;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Hanya menerima POST." }, 405);
  }

  // Supabase meneruskan sisa path sesudah nama fungsi, jadi satu fungsi bisa
  // melayani kedua webhook tanpa dua kali deploy.
  const route = new URL(req.url).pathname.split("/").filter(Boolean).pop();

  let payload: SignedPayload;
  try {
    payload = await readSignedRequest(req);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 400);
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  if (route === "deauthorize") {
    await disconnect(admin, payload.user_id, "deauthorize");
    // Meta hanya peduli statusnya 200; badannya tidak dibaca.
    return json({ ok: true });
  }

  if (route === "data-deletion") {
    await disconnect(admin, payload.user_id, "data-deletion");

    // Kode ini yang ditunjukkan pengguna kalau mereka ingin menanyakan
    // status permintaannya. Karena tidak ada data yang tertahan dalam
    // antrean — penghapusannya selesai seketika di baris atas — kodenya
    // hanya perlu unik, bukan penunjuk ke pekerjaan yang masih berjalan.
    const confirmationCode = crypto.randomUUID().replaceAll("-", "");

    return json({
      url: `${PUBLIC_SITE_URL}/threads-data-deletion?code=${confirmationCode}`,
      confirmation_code: confirmationCode,
    });
  }

  return json({ error: `Rute tidak dikenal: ${route}` }, 404);
});

// Melepas akun yang dicabut izinnya. Dibatasi ke external_user_id yang
// disebut Meta supaya webhook untuk akun lain tidak ikut mematikan auto-post
// akun kita.
async function disconnect(
  admin: ReturnType<typeof createClient>,
  userId: string | undefined,
  reason: string,
): Promise<void> {
  if (!userId) return;

  const { error } = await admin
    .from("social_accounts")
    .delete()
    .eq("platform", "threads")
    .eq("external_user_id", userId);

  if (error) {
    console.error(`Gagal melepas akun Threads (${reason}):`, error.message);
    return;
  }

  console.log(`Akun Threads ${userId} dilepas karena ${reason}.`);
}

// ---------------------------------------------------------------------------
// Verifikasi signed_request
// ---------------------------------------------------------------------------

// Meta mengirim `signed_request` berupa "<signature>.<payload>", keduanya
// base64url. Tanpa memverifikasi tanda tangannya, siapa pun yang tahu URL ini
// bisa menghapus token kita hanya dengan mengirim POST — makanya verifikasi
// ini tidak boleh dilewati.
async function readSignedRequest(req: Request): Promise<SignedPayload> {
  const form = await req.formData().catch(() => null);
  const signedRequest = form?.get("signed_request");

  if (typeof signedRequest !== "string" || !signedRequest.includes(".")) {
    throw new Error("signed_request tidak ada atau formatnya salah.");
  }

  const [encodedSig, encodedPayload] = signedRequest.split(".", 2);

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(THREADS_APP_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    base64UrlToBytes(encodedSig),
    new TextEncoder().encode(encodedPayload),
  );

  if (!valid) {
    throw new Error("Tanda tangan signed_request tidak cocok.");
  }

  const payload = JSON.parse(
    new TextDecoder().decode(base64UrlToBytes(encodedPayload)),
  ) as SignedPayload;

  if (payload.algorithm && payload.algorithm.toUpperCase() !== "HMAC-SHA256") {
    throw new Error(`Algoritma tak didukung: ${payload.algorithm}`);
  }

  return payload;
}

function base64UrlToBytes(value: string) {
  const padded = value.replaceAll("-", "+").replaceAll("_", "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  // Buffer-nya dibuat eksplisit supaya hasilnya tetap diterima sebagai
  // BufferSource oleh crypto.subtle di TypeScript versi baru.
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

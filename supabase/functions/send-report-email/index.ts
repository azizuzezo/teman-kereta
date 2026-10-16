// Emails a support report to the support inbox through Cloudflare Email Service.
//
// Trigger: AFTER INSERT on public.app_reports, via pg_net (see
// supabase/migrations/20261016090000_app_reports.sql). The trigger only sends
// {"id": "<uuid>"}; this function re-reads the row with the service role, so
// the email content always comes from the database, never from the caller.
//
// Auth: header `x-webhook-secret` must equal the WEBHOOK_SECRET secret. The
// Supabase gateway also requires a JWT (the trigger sends the anon key), so no
// config.toml change is needed. Never put real secrets in this repo.
//
// Secrets (supabase secrets set ...), documented in docs/support-reports.md:
//   CLOUDFLARE_ACCOUNT_ID  Cloudflare account id
//   CLOUDFLARE_API_TOKEN   API token with the Email Sending permission
//   SUPPORT_EMAIL          recipient, e.g. support@temankereta.web.id
//   WEBHOOK_SECRET         shared secret, same value as the Vault secret
//   EMAIL_FROM             optional sender, default laporan@temankereta.web.id
//                          (the domain must be onboarded in Email Sending)
//
// Deploy (run by the project owner, nothing here has been deployed):
//   supabase functions deploy send-report-email
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  buildCloudflarePayload,
  interpretCloudflareResponse,
  type ReportRow,
  safeEqual,
  shortId,
} from "./format.ts";

const MAX_ATTEMPTS_PER_CALL = 3;
const CLOUDFLARE_BASE = "https://api.cloudflare.com/client/v4";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const env = {
    supabaseUrl: Deno.env.get("SUPABASE_URL"),
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    accountId: Deno.env.get("CLOUDFLARE_ACCOUNT_ID"),
    apiToken: Deno.env.get("CLOUDFLARE_API_TOKEN"),
    to: Deno.env.get("SUPPORT_EMAIL"),
    secret: Deno.env.get("WEBHOOK_SECRET"),
    from: Deno.env.get("EMAIL_FROM") ?? "laporan@temankereta.web.id",
  };
  const missing = Object.entries({
    SUPABASE_URL: env.supabaseUrl,
    SUPABASE_SERVICE_ROLE_KEY: env.serviceKey,
    CLOUDFLARE_ACCOUNT_ID: env.accountId,
    CLOUDFLARE_API_TOKEN: env.apiToken,
    SUPPORT_EMAIL: env.to,
    WEBHOOK_SECRET: env.secret,
  }).filter(([, v]) => !v).map(([k]) => k);
  if (missing.length > 0) {
    // Names only, never values.
    return json({ error: `Secret belum diisi: ${missing.join(", ")}` }, 500);
  }

  const provided = req.headers.get("x-webhook-secret") ?? "";
  if (!safeEqual(provided, env.secret!)) {
    return json({ error: "Unauthorized" }, 401);
  }

  let id: string | undefined;
  try {
    const body = await req.json();
    // Accept both {"id": "..."} and the Supabase Database Webhook shape.
    id = body?.id ?? body?.record?.id;
  } catch {
    return json({ error: "Body bukan JSON" }, 400);
  }
  if (typeof id !== "string" || !/^[0-9a-f-]{36}$/i.test(id)) {
    return json({ error: "id laporan tidak valid" }, 400);
  }

  const admin = createClient(env.supabaseUrl!, env.serviceKey!, {
    auth: { persistSession: false },
  });

  const { data, error: readError } = await admin
    .from("app_reports")
    .select(
      "id, user_id, category, message, contact_email, app_version, build_number, platform, os_version, device_model, diagnostics, log_text, created_at, email_status, email_attempts",
    )
    .eq("id", id)
    .maybeSingle();

  if (readError) {
    return json({ error: `Gagal membaca laporan: ${readError.message}` }, 500);
  }
  if (!data) {
    return json({ error: "Laporan tidak ditemukan" }, 404);
  }
  if (data.email_status === "sent") {
    return json({ id, skipped: "sudah terkirim" });
  }

  const row = data as ReportRow & { email_status: string };
  const payload = buildCloudflarePayload(row, { to: env.to!, from: env.from });

  let outcome = { ok: false, retryable: true, error: "belum dicoba" } as {
    ok: boolean;
    retryable: boolean;
    error?: string;
  };
  for (let attempt = 1; attempt <= MAX_ATTEMPTS_PER_CALL; attempt++) {
    try {
      const res = await fetch(
        `${CLOUDFLARE_BASE}/accounts/${env.accountId}/email/sending/send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${env.apiToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(payload),
        },
      );
      const body = await res.json().catch(() => null);
      outcome = interpretCloudflareResponse(res.status, body, env.to!);
    } catch (error) {
      outcome = {
        ok: false,
        retryable: true,
        error: `Jaringan: ${error instanceof Error ? error.message : String(error)}`,
      };
    }
    if (outcome.ok || !outcome.retryable || attempt === MAX_ATTEMPTS_PER_CALL) {
      break;
    }
    await sleep(500 * 3 ** (attempt - 1)); // 500 ms, 1.5 s
  }

  const attempts = (row.email_attempts ?? 0) + 1;
  const { error: updateError } = await admin
    .from("app_reports")
    .update(
      outcome.ok
        ? {
          email_status: "sent",
          email_sent_at: new Date().toISOString(),
          email_error: null,
          email_attempts: attempts,
        }
        : {
          email_status: "failed",
          email_error: (outcome.error ?? "gagal").slice(0, 900),
          email_attempts: attempts,
        },
    )
    .eq("id", id);

  if (updateError) {
    console.error(`app_reports ${shortId(id)} update gagal: ${updateError.message}`);
  }
  console.log(
    `app_reports ${shortId(id)} email ${outcome.ok ? "sent" : "failed"} (attempt ${attempts})`,
  );

  return outcome.ok
    ? json({ id, status: "sent" })
    : json({ id, status: "failed", error: outcome.error }, 502);
});

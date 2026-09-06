// Sends a real Firebase Cloud Messaging push to one or more users, by
// looking up their registered tokens in public.device_tokens (populated by
// the Flutter app's PushTokenRegistrar once a real google-services.json is
// configured — see lib/core/notifications/push_token_registrar.dart).
//
// Auth: this function is meant to be called by trusted server-side/admin
// code only (e.g. the admin panel, or another Edge Function) using the
// service role key — it is not exposed to end users, so unlike
// premium-check-payment it does not authenticate an end-user JWT.
//
// Deploy (run by the project owner — no Supabase CLI auth in this
// environment):
//   supabase functions deploy send-push-notification
//   supabase secrets set FIREBASE_PROJECT_ID=...
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='<the full service account JSON>'
import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT_JSON",
)!;

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

interface SendPushRequest {
  user_ids: string[];
  title: string;
  body: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user_ids, title, body } = (await req.json().catch(() => ({}))) as
      Partial<SendPushRequest>;

    if (
      !Array.isArray(user_ids) || user_ids.length === 0 ||
      typeof title !== "string" || title.trim() === "" ||
      typeof body !== "string" || body.trim() === ""
    ) {
      return json(
        { error: "user_ids (array), title, dan body wajib diisi." },
        400,
      );
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: tokenRows, error: tokenError } = await admin
      .from("device_tokens")
      .select("id, fcm_token")
      .in("user_id", user_ids);

    if (tokenError) {
      return json({ error: `Gagal membaca device_tokens: ${tokenError.message}` }, 500);
    }
    if (!tokenRows || tokenRows.length === 0) {
      return json({ sent: 0, failed: 0, cleaned_up: 0 });
    }

    const accessToken = await getGoogleAccessToken();

    let sent = 0;
    let failed = 0;
    let cleanedUp = 0;

    for (const row of tokenRows) {
      const fcmToken = row.fcm_token as string;
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: fcmToken,
              notification: { title, body },
            },
          }),
        },
      );

      if (response.ok) {
        sent++;
        continue;
      }

      failed++;
      const errorBody = await response.json().catch(() => null);
      const status: string | undefined = errorBody?.error?.status;
      if (status === "UNREGISTERED" || status === "NOT_FOUND") {
        await admin.from("device_tokens").delete().eq("id", row.id);
        cleanedUp++;
      }
    }

    return json({ sent, failed, cleaned_up: cleanedUp });
  } catch (error) {
    return json({ error: `Terjadi kesalahan: ${error}` }, 500);
  }
});

// Mints a short-lived OAuth2 access token for the FCM HTTP v1 API from the
// service account credentials, via the standard Google service-account
// JWT-bearer flow (RFC 7523): sign a claim set with the service account's
// RSA private key, then exchange it at Google's token endpoint.
async function getGoogleAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(
    FIREBASE_SERVICE_ACCOUNT_JSON,
  ) as ServiceAccount;

  const privateKey = await importPKCS8(serviceAccount.private_key, "RS256");

  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({ scope: FCM_SCOPE })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setAudience(OAUTH_TOKEN_URL)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const tokenResponse = await fetch(OAUTH_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!tokenResponse.ok) {
    throw new Error(
      `Gagal menukar JWT untuk access token Google: ${await tokenResponse.text()}`,
    );
  }

  const tokenBody = await tokenResponse.json();
  return tokenBody.access_token as string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

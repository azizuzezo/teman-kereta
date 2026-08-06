// Confirms a pending QRIS payment (created via premium-create-payment) and,
// once paid, extends/activates the caller's row in public.subscriptions.
// This is the authoritative write path — the Flutter client only ever
// reads subscriptions via Supabase Realtime, it never sets status itself.
//
// Deploy (run by the project owner — no Supabase CLI auth here):
//   supabase functions deploy premium-check-payment
//   supabase secrets set GOPAY_API_URL=... GOPAY_API_KEY=...
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const GOPAY_API_URL = Deno.env.get("GOPAY_API_URL")!;
const GOPAY_API_KEY = Deno.env.get("GOPAY_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Sesi tidak ditemukan. Masuk lagi lalu coba ulang." }, 401);
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: "Sesi tidak valid. Masuk lagi lalu coba ulang." }, 401);
    }
    const userId = userData.user.id;

    const { payment_id } = await req.json().catch(() => ({}));
    if (!payment_id) {
      return json({ error: "payment_id wajib diisi." }, 400);
    }

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: payment } = await admin
      .from("premium_payments")
      .select()
      .eq("id", payment_id)
      .maybeSingle();

    if (!payment || payment.user_id !== userId) {
      return json({ error: "Pembayaran tidak ditemukan." }, 404);
    }

    if (payment.status === "paid") {
      const entitlement = await fetchEntitlement(admin, userId);
      return json({ paid: true, subscription: entitlement });
    }

    const gatewayResponse = await fetch(
      `${GOPAY_API_URL}/api/qr-status/${payment.qris_id}`,
      { headers: { "X-API-Key": GOPAY_API_KEY } },
    );
    const gatewayBody = await gatewayResponse.json();

    if (gatewayBody.status === "EXPIRED") {
      await admin
        .from("premium_payments")
        .update({ status: "expired" })
        .eq("id", payment_id);
      return json({ paid: false, expired: true });
    }

    if (!gatewayBody.paid) {
      return json({ paid: false });
    }

    await admin
      .from("premium_payments")
      .update({
        status: "paid",
        paid_at: new Date().toISOString(),
        trx_id: gatewayBody.transaction?.transaction_id ?? payment.trx_id,
      })
      .eq("id", payment_id);

    const { data: configRow } = await admin
      .from("app_config")
      .select("value")
      .eq("key", "remote_config")
      .maybeSingle();
    const periodDays = Number(
      (configRow?.value as Record<string, unknown> | null)?.premium_period_days ?? 30,
    );

    const { data: existing } = await admin
      .from("subscriptions")
      .select()
      .eq("user_id", userId)
      .maybeSingle();

    const now = new Date();
    const existingPeriodEnd = existing?.current_period_end
      ? new Date(existing.current_period_end)
      : null;
    const extensionBase =
      existingPeriodEnd && existingPeriodEnd > now ? existingPeriodEnd : now;
    const newPeriodEnd = new Date(
      extensionBase.getTime() + periodDays * 24 * 60 * 60 * 1000,
    );

    await admin.from("subscriptions").upsert({
      user_id: userId,
      status: "active",
      current_period_end: newPeriodEnd.toISOString(),
      trial_ends_at: existing?.trial_ends_at ?? null,
    });

    const entitlement = await fetchEntitlement(admin, userId);
    return json({ paid: true, subscription: entitlement });
  } catch (error) {
    return json({ error: `Terjadi kesalahan: ${error}` }, 500);
  }
});

// deno-lint-ignore no-explicit-any
async function fetchEntitlement(admin: any, userId: string) {
  const { data } = await admin
    .from("subscriptions")
    .select()
    .eq("user_id", userId)
    .maybeSingle();
  return data;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

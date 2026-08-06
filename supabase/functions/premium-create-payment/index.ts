// Creates a QRIS payment intent for the premium station-reminder
// subscription (see supabase/migrations/20260806140000_premium_subscriptions.sql).
//
// Calls the merchant's own GoPay Partner API Gateway directly — GOPAY_API_URL/
// GOPAY_API_KEY are Edge Function secrets, never shipped in the Flutter app.
// Deploy with (run by the project owner, not from this environment — no
// Supabase CLI auth is available here):
//   supabase functions deploy premium-create-payment
//   supabase secrets set GOPAY_API_URL=... GOPAY_API_KEY=...
//
// The gateway matches incoming GoPay/QRIS payments by nominal amount within
// a time window, so two riders paying the exact listed price in the same
// ~5-minute QR-expiry window could collide. Mitigated (not eliminated) by
// adding a small random Rupiah offset (1-99) on top of the configured
// price, then verifying via /api/qr-status/:qris_id (id-scoped, not
// amount-scoped) in premium-check-payment.
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

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: configRow } = await admin
      .from("app_config")
      .select("value")
      .eq("key", "remote_config")
      .maybeSingle();
    const config = (configRow?.value ?? {}) as Record<string, unknown>;
    const basePrice = Number(config.premium_price_idr ?? 15000);

    // Small unique offset so this transaction's exact nominal amount is
    // unlikely to collide with another rider's pending QR in the same
    // window — see file header.
    const offset = 1 + Math.floor(Math.random() * 99);
    const amount = basePrice + offset;

    const gatewayResponse = await fetch(
      `${GOPAY_API_URL}/create-qris?amount=${amount}`,
      { headers: { "X-API-Key": GOPAY_API_KEY } },
    );
    const gatewayBody = await gatewayResponse.json();
    if (!gatewayResponse.ok || !gatewayBody.success) {
      return json(
        { error: gatewayBody.message ?? "Gagal membuat pembayaran. Coba lagi." },
        502,
      );
    }

    const { qris_id, trx_id, qris_url, qris_code, expires_at } = gatewayBody.data;

    const { data: paymentRow, error: insertError } = await admin
      .from("premium_payments")
      .insert({
        user_id: userId,
        qris_id,
        trx_id,
        amount,
        status: "pending",
        expires_at,
      })
      .select()
      .single();

    if (insertError || !paymentRow) {
      return json({ error: "Gagal mencatat pembayaran. Coba lagi." }, 500);
    }

    return json({
      payment_id: paymentRow.id,
      qris_id,
      qris_url,
      qris_code,
      amount,
      expires_at,
    });
  } catch (error) {
    return json({ error: `Terjadi kesalahan: ${error}` }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

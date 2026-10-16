// Run with Deno:   deno test supabase/functions/send-report-email/format_test.ts
// Or with Node 22+: node --experimental-strip-types --test supabase/functions/send-report-email/format_test.ts
// Uses only node:test + node:assert so both runners work (Deno supports both).
import assert from "node:assert/strict";
import test from "node:test";
import {
  buildCloudflarePayload,
  buildSubject,
  buildTextReport,
  interpretCloudflareResponse,
  type ReportRow,
  safeEqual,
  shortId,
  singleLine,
} from "./format.ts";

const row: ReportRow = {
  id: "3f2b8c1e-7a4d-4e0a-9b1f-2c5d6e7f8a90",
  user_id: "11111111-2222-4333-8444-555555555555",
  category: "notification",
  message: "  Suara tidak keluar saat 1 stasiun lagi.  ",
  contact_email: null,
  app_version: "1.0.17",
  build_number: "18",
  platform: "Android",
  os_version: "14 (SDK 34)",
  device_model: "Xiaomi 2201117TG",
  diagnostics: {
    format: 1,
    app: { name: "Teman Kereta", environment: "remote", transit_provider: "local_supabase", theme_mode: "light", palette: "navyKrl" },
    device: { platform: "Android", os_version: "14 (SDK 34)", manufacturer: "Xiaomi", model: "2201117TG", locale: "id-ID", timezone: "WIB (UTC+07:00)", connectivity: "wifi" },
    status: { location_service_enabled: true, location_permission: "always", background_location_granted: false, notification_permission_granted: true, battery_optimization_exempt: false, user_id: "11111111-2222-4333-8444-555555555555", active_trip: null, last_error: null },
  },
  log_text: Array.from({ length: 100 }, (_, i) => `line ${i}`).join("\n"),
  created_at: "2026-10-15T03:22:11.000Z",
};

test("subject follows the agreed pattern", () => {
  assert.equal(
    buildSubject(row),
    "[Laporan #3F2B8C1E] Notifikasi atau suara tidak berbunyi - Teman Kereta v1.0.17",
  );
});

test("subject cannot be used for header injection", () => {
  const evil = { ...row, app_version: "1.0\r\nBcc: attacker@example.com" };
  assert.ok(!/[\r\n]/.test(buildSubject(evil)));
  assert.equal(singleLine("a\r\nb"), "a b");
});

test("text report has the fixed header, sections in order and footer", () => {
  const text = buildTextReport(row);
  const lines = text.split("\n");
  assert.equal(lines[0], "=== TEMAN KERETA LAPORAN ===");
  assert.equal(lines.at(-1), "=== AKHIR LAPORAN ===");
  let cursor = -1;
  for (const marker of ["[Ringkasan]", "Pesan:", "[Perangkat]", "[Aplikasi]", "[Status]", "[Log terbaru] (100 baris)"]) {
    const i = lines.indexOf(marker);
    assert.ok(i > cursor, `${marker} out of order`);
    cursor = i;
  }
  assert.match(text, /Perangkat: Xiaomi 2201117TG/);
  assert.match(text, /Bebas hemat baterai: tidak\n/);
  assert.match(text, /Kontak: tidak dicantumkan/);
});

test("inline log is trimmed to the newest lines, full log goes in the attachment", () => {
  const payload = buildCloudflarePayload(row, { to: "support@temankereta.web.id", from: "laporan@temankereta.web.id" });
  const text = payload.text as string;
  assert.match(text, /\[Log terbaru\] \(40 dari 100 baris, selengkapnya di lampiran\)/);
  assert.ok(text.includes("line 99") && !text.includes("line 10\n"));
  const attachments = payload.attachments as { filename: string; content: string }[];
  assert.equal(attachments[0].filename, "log-3F2B8C1E.txt");
  assert.equal(Buffer.from(attachments[0].content, "base64").toString("utf8"), row.log_text);
});

test("no log means no attachment and a clear note", () => {
  const noLog = { ...row, log_text: null };
  const payload = buildCloudflarePayload(noLog, { to: "a@b.id", from: "c@d.id" });
  assert.equal(payload.attachments, undefined);
  assert.match(payload.text as string, /\(tidak disertakan\)/);
  assert.match(payload.text as string, /Log ikut terkirim: tidak/);
});

test("payload uses the REST field names and html is escaped", () => {
  const xss = { ...row, message: "<script>alert(1)</script>", contact_email: "budi@mail.com" };
  const payload = buildCloudflarePayload(xss, { to: "support@temankereta.web.id", from: "laporan@temankereta.web.id" });
  assert.equal(payload.to, "support@temankereta.web.id");
  assert.equal(payload.from, "laporan@temankereta.web.id");
  assert.equal(payload.reply_to, "budi@mail.com");
  assert.ok(!(payload.html as string).includes("<script>"));
  assert.ok((payload.html as string).includes("&lt;script&gt;"));
});

test("invalid contact e-mail is not used as reply_to", () => {
  const payload = buildCloudflarePayload({ ...row, contact_email: "bukan email" }, { to: "a@b.id", from: "c@d.id" });
  assert.equal(payload.reply_to, undefined);
});

test("cloudflare response interpretation", () => {
  const to = "support@temankereta.web.id";
  assert.deepEqual(
    interpretCloudflareResponse(200, { success: true, result: { delivered: [to], queued: [], permanent_bounces: [] } }, to),
    { ok: true, retryable: false },
  );
  assert.equal(interpretCloudflareResponse(200, { success: true, result: { delivered: [], queued: [to], permanent_bounces: [] } }, to).ok, true);
  assert.equal(interpretCloudflareResponse(200, { success: true, result: { delivered: [], queued: [], permanent_bounces: [to] } }, to).ok, false);
  const throttled = interpretCloudflareResponse(429, { success: false, errors: [{ code: 10004, message: "throttled" }], result: null }, to);
  assert.equal(throttled.retryable, true);
  assert.match(throttled.error!, /10004/);
  const unauthorized = interpretCloudflareResponse(401, { success: false, errors: [{ code: 10101, message: "unauthorized" }] }, to);
  assert.equal(unauthorized.retryable, false);
  assert.equal(interpretCloudflareResponse(500, null, to).retryable, true);
});

test("safeEqual and shortId", () => {
  assert.ok(safeEqual("abc", "abc"));
  assert.ok(!safeEqual("abc", "abd"));
  assert.ok(!safeEqual("abc", "abcd"));
  assert.ok(!safeEqual("", "x"));
  assert.equal(shortId("abcdef12-0000-0000-0000-000000000000"), "ABCDEF12");
});

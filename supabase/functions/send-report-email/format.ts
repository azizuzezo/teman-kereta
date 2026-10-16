// Pure helpers for send-report-email: no Deno or network APIs here, so they
// can be unit-tested with plain Node/Deno (see format_test.ts).
//
// The plain-text layout mirrors DiagnosticsFormatter.toText in the Flutter app
// (lib/core/diagnostics/diagnostics_report.dart): same header, same sections.

export interface ReportRow {
  id: string;
  user_id: string | null;
  category: string;
  message: string;
  contact_email: string | null;
  app_version: string | null;
  build_number: string | null;
  platform: string | null;
  os_version: string | null;
  device_model: string | null;
  diagnostics: Record<string, unknown> | null;
  log_text: string | null;
  created_at: string;
  email_attempts?: number;
}

export const CATEGORY_LABELS: Record<string, string> = {
  schedule: "Jadwal salah",
  notification: "Notifikasi atau suara tidak berbunyi",
  map: "Peta atau posisi kereta",
  forum: "Forum atau penyalahgunaan",
  account: "Akun atau login",
  other: "Lainnya",
};

export const UNKNOWN = "tidak diketahui";
export const INLINE_LOG_LINES = 40;

export function shortId(id: string): string {
  return id.replaceAll("-", "").slice(0, 8).toUpperCase();
}

/** Removes CR/LF and other control characters so a value can never inject headers. */
export function singleLine(value: string): string {
  // deno-lint-ignore no-control-regex
  return value.replace(/[\u0000-\u001f\u007f]+/g, " ").trim();
}

export function categoryLabel(code: string): string {
  return CATEGORY_LABELS[code] ?? code;
}

export function buildSubject(row: ReportRow): string {
  const version = singleLine(row.app_version ?? "?");
  return `[Laporan #${shortId(row.id)}] ${categoryLabel(row.category)} - Teman Kereta v${version}`;
}

type Dict = Record<string, unknown>;

function dict(value: unknown): Dict {
  return value && typeof value === "object" ? (value as Dict) : {};
}

function str(value: unknown): string {
  return value === null || value === undefined || value === ""
    ? UNKNOWN
    : String(value);
}

function yesNo(value: unknown, yes = "ya", no = "tidak"): string {
  return typeof value === "boolean" ? (value ? yes : no) : UNKNOWN;
}

/** Fixed-layout report, same section order as the in-app preview. */
export function buildTextReport(
  row: ReportRow,
  options: { logLines?: number } = {},
): string {
  const d = dict(row.diagnostics);
  const app = dict(d.app);
  const device = dict(d.device);
  const status = dict(d.status);
  const model = [device.manufacturer, device.model]
    .filter((v) => typeof v === "string" && v)
    .join(" ");

  const out: string[] = [
    "=== TEMAN KERETA LAPORAN ===",
    `Format: ${str(d.format)}`,
    `ID: ${row.id} (#${shortId(row.id)})`,
    `Dibuat: ${row.created_at}`,
    "",
    "[Ringkasan]",
    `Kategori: ${categoryLabel(row.category)}`,
    `Kontak: ${row.contact_email ?? "tidak dicantumkan"}`,
    `Log ikut terkirim: ${row.log_text ? "ya" : "tidak (dimatikan pengguna)"}`,
    "",
    "Pesan:",
    row.message.trim(),
    "",
    "[Perangkat]",
    `Platform: ${str(device.platform ?? row.platform)} ${str(device.os_version ?? row.os_version)}`,
    `Perangkat: ${model || str(row.device_model)}`,
    `Bahasa: ${str(device.locale)}`,
    `Zona waktu: ${str(device.timezone)}`,
    `Koneksi: ${str(device.connectivity)}`,
    "",
    "[Aplikasi]",
    `Nama: ${str(app.name ?? "Teman Kereta")}`,
    `Versi: ${row.app_version ? `${row.app_version}${row.build_number ? ` (${row.build_number})` : ""}` : UNKNOWN}`,
    `Lingkungan: ${str(app.environment)}`,
    `Sumber data: ${str(app.transit_provider)}`,
    `Tema: ${str(app.theme_mode)} / ${str(app.palette)}`,
    "",
    "[Status]",
    `Layanan lokasi: ${yesNo(status.location_service_enabled, "aktif", "mati")}`,
    `Izin lokasi: ${str(status.location_permission)}`,
    `Izin lokasi latar: ${yesNo(status.background_location_granted, "diberikan", "tidak diberikan")}`,
    `Izin notifikasi: ${yesNo(status.notification_permission_granted, "diberikan", "tidak diberikan")}`,
    `Bebas hemat baterai: ${yesNo(status.battery_optimization_exempt)}`,
    `Akun: ${status.user_id ? `masuk (id ${status.user_id})` : row.user_id ? `masuk (id ${row.user_id})` : "tidak masuk"}`,
    `Perjalanan aktif: ${status.active_trip ? String(status.active_trip) : "tidak ada"}`,
    `Error terakhir: ${status.last_error ? String(status.last_error) : "tidak ada"}`,
    "",
  ];

  const limit = options.logLines;
  if (!row.log_text) {
    out.push("[Log terbaru]", "(tidak disertakan)");
  } else {
    const lines = row.log_text.split("\n");
    const shown = limit === undefined ? lines : lines.slice(-limit);
    out.push(
      limit !== undefined && lines.length > shown.length
        ? `[Log terbaru] (${shown.length} dari ${lines.length} baris, selengkapnya di lampiran)`
        : `[Log terbaru] (${lines.length} baris)`,
      ...shown,
    );
  }
  out.push("", "=== AKHIR LAPORAN ===");
  return out.join("\n");
}

export function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function buildHtml(text: string): string {
  return `<!doctype html><html><body><pre style="font-family:Menlo,Consolas,monospace;font-size:13px;line-height:1.45;white-space:pre-wrap;word-break:break-word">${escapeHtml(text)}</pre></body></html>`;
}

export function toBase64(text: string): string {
  const bytes = new TextEncoder().encode(text);
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

export interface EmailConfig {
  to: string;
  from: string;
}

/** Body for POST /accounts/{id}/email/sending/send (REST field names). */
export function buildCloudflarePayload(row: ReportRow, config: EmailConfig) {
  const text = buildTextReport(row, { logLines: INLINE_LOG_LINES });
  const payload: Record<string, unknown> = {
    to: config.to,
    from: config.from,
    subject: buildSubject(row),
    text,
    html: buildHtml(text),
  };
  if (row.contact_email && /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(row.contact_email)) {
    payload.reply_to = row.contact_email;
  }
  if (row.log_text) {
    payload.attachments = [
      {
        content: toBase64(row.log_text),
        filename: `log-${shortId(row.id)}.txt`,
        type: "text/plain",
        disposition: "attachment",
      },
    ];
  }
  return payload;
}

export interface CloudflareResult {
  ok: boolean;
  retryable: boolean;
  error?: string;
}

/** Interprets Cloudflare's send response (HTTP status + JSON body). */
export function interpretCloudflareResponse(
  httpStatus: number,
  body: unknown,
  recipient: string,
): CloudflareResult {
  const b = dict(body);
  const result = dict(b.result);
  const delivered = Array.isArray(result.delivered) ? result.delivered as string[] : [];
  const queued = Array.isArray(result.queued) ? result.queued as string[] : [];
  const bounced = Array.isArray(result.permanent_bounces)
    ? result.permanent_bounces as string[]
    : [];

  if (httpStatus >= 200 && httpStatus < 300 && b.success === true) {
    if (bounced.includes(recipient)) {
      return { ok: false, retryable: false, error: "permanent bounce dari penerima" };
    }
    if (delivered.includes(recipient) || queued.includes(recipient)) {
      return { ok: true, retryable: false };
    }
    // Success without our address listed (e.g. suppressed): do not loop.
    return { ok: false, retryable: false, error: "Cloudflare tidak mencantumkan penerima di delivered/queued" };
  }

  const errors = Array.isArray(b.errors) ? b.errors as Dict[] : [];
  const detail = errors.map((e) => `${e.code ?? "?"}: ${e.message ?? "?"}`).join("; ");
  const retryable = httpStatus === 429 || httpStatus >= 500;
  return {
    ok: false,
    retryable,
    error: `HTTP ${httpStatus}${detail ? ` ${detail}` : ""}`.slice(0, 900),
  };
}

/** Constant-time string comparison for the webhook secret. */
export function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const len = Math.max(x.length, y.length);
  for (let i = 0; i < len; i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

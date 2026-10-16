import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { SubmitButton } from "@/components/ui/button";
import { Card, Section } from "@/components/ui/card";
import { SelectField } from "@/components/ui/fields";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { updateAppReportStatus } from "../actions";
import { CATEGORY_LABELS, formatDate } from "../format";

export const metadata: Metadata = { title: "Detail laporan aplikasi" };

const STATUS_OPTIONS: { value: string; label: string }[] = [
  { value: "open", label: "Baru" },
  { value: "in_progress", label: "Diproses" },
  { value: "resolved", label: "Selesai" },
  { value: "dismissed", label: "Ditolak" },
];

export default async function AppReportDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await verifyAdminSession();
  const { id } = await params;
  const supabase = createServiceClient();
  const { data: report, error } = await supabase
    .from("app_reports")
    .select("*")
    .eq("id", id)
    .maybeSingle();

  if (error) {
    return (
      <div className="flex flex-col gap-6">
        <PageHeader
          title="Detail laporan aplikasi"
          back={{ href: "/app-reports", label: "Kembali ke daftar laporan" }}
        />
        <LoadError what="Detail laporan" error={error} />
      </div>
    );
  }
  if (!report) {
    notFound();
  }

  const shortId = report.id.slice(0, 8).toUpperCase();
  const diagnostics = JSON.stringify(report.diagnostics ?? {}, null, 2);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={`Laporan #${shortId}`}
        description={`${CATEGORY_LABELS[report.category] ?? report.category} · ${formatDate(report.created_at)}`}
        back={{ href: "/app-reports", label: "Kembali ke daftar laporan" }}
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <StatusBadge status={report.status} />
            <StatusBadge status={`email ${report.email_status}`} />
          </div>
        }
      />

      <Card>
        <h2 className="text-base font-bold text-ink">Pesan pengguna</h2>
        <p className="mt-2 whitespace-pre-wrap break-words text-sm text-ink">
          {report.message}
        </p>
        <dl className="mt-4 grid gap-x-6 gap-y-2 text-sm sm:grid-cols-2">
          <Meta label="Versi aplikasi">
            {report.app_version ?? "-"}
            {report.build_number ? ` (build ${report.build_number})` : ""}
          </Meta>
          <Meta label="Perangkat">{report.device_model ?? "-"}</Meta>
          <Meta label="Sistem operasi">
            {[report.platform, report.os_version].filter(Boolean).join(" ") ||
              "-"}
          </Meta>
          <Meta label="Email kontak">
            {report.contact_email ? (
              <a
                className="text-brand hover:underline"
                href={`mailto:${report.contact_email}`}
              >
                {report.contact_email}
              </a>
            ) : (
              "Tidak disertakan"
            )}
          </Meta>
          <Meta label="Akun">{report.user_id ?? "Tidak masuk"}</Meta>
          <Meta label="Email ke support">
            {report.email_status === "sent" && report.email_sent_at
              ? `Terkirim ${formatDate(report.email_sent_at)}`
              : report.email_status === "failed"
                ? `Gagal: ${report.email_error ?? "tanpa keterangan"}`
                : "Menunggu"}
          </Meta>
        </dl>
      </Card>

      <Card>
        <h2 className="text-base font-bold text-ink">Tindak lanjut</h2>
        <form
          action={updateAppReportStatus}
          className="mt-3 flex flex-wrap items-end gap-3"
        >
          <input type="hidden" name="id" value={report.id} />
          <SelectField
            label="Status laporan"
            name="status"
            id="status"
            defaultValue={report.status}
            fieldClassName="min-w-48"
          >
            {STATUS_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </SelectField>
          <SubmitButton loadingLabel="Menyimpan…">Simpan status</SubmitButton>
        </form>
      </Card>

      <Section
        title="Log aplikasi"
        description="Sudah disamarkan di perangkat (token, email, nomor telepon). Dibaca terbaru di bagian bawah."
        actions={
          <Badge tone={report.log_text ? "brand" : "neutral"}>
            {report.log_text
              ? `${report.log_text.split("\n").length} baris`
              : "Dimatikan pengguna"}
          </Badge>
        }
      >
        {report.log_text ? (
          <pre
            tabIndex={0}
            aria-label="Isi log aplikasi"
            className="max-h-[32rem] overflow-auto rounded-card border border-line bg-surface-alt p-4 text-xs leading-relaxed text-ink"
          >
            {report.log_text}
          </pre>
        ) : (
          <Card tone="soft">
            <p className="text-sm text-ink">
              Pengguna mematikan pengiriman log untuk laporan ini.
            </p>
          </Card>
        )}
      </Section>

      <Section
        title="Ringkasan diagnostik"
        description="Perangkat, aplikasi, dan status izin saat laporan dikirim."
      >
        <pre
          tabIndex={0}
          aria-label="Ringkasan diagnostik dalam JSON"
          className="max-h-96 overflow-auto rounded-card border border-line bg-surface-alt p-4 text-xs leading-relaxed text-ink"
        >
          {diagnostics}
        </pre>
      </Section>
    </div>
  );
}

function Meta({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="min-w-0">
      <dt className="text-xs font-semibold text-ink-muted">{label}</dt>
      <dd className="break-words text-ink">{children}</dd>
    </div>
  );
}

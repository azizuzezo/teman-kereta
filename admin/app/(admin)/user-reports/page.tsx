import type { Metadata } from "next";
import { StatusBadge } from "@/components/ui/badge";
import { SubmitButton } from "@/components/ui/button";
import { SelectField } from "@/components/ui/fields";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { RecordCard, RecordList } from "@/components/ui/record-card";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { moderateUserReport } from "./actions";

export const metadata: Metadata = { title: "Laporan pengguna" };

const STATUSES = ["pending", "verified", "rejected", "resolved", "expired"];

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function UserReportsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: reports, error } = await supabase
    .from("user_reports")
    .select(
      "id, report_type, description, status, created_at, expires_at, stations(name), lines(name)"
    )
    .order("created_at", { ascending: false })
    .limit(100);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Laporan pengguna"
        description="Moderasi laporan kondisi yang dikirim pengguna dari aplikasi. Menampilkan 100 laporan terbaru."
      />

      {error ? (
        <LoadError what="Daftar laporan pengguna" error={error} />
      ) : (
        <RecordList
          isEmpty={(reports ?? []).length === 0}
          empty={{
            title: "Belum ada laporan pengguna",
            description: "Laporan dari aplikasi akan muncul di sini.",
          }}
        >
          {(reports ?? []).map((report) => {
            const stationName = (
              report.stations as unknown as { name: string } | null
            )?.name;
            const lineName = (report.lines as unknown as { name: string } | null)
              ?.name;
            const place = [stationName, lineName].filter(Boolean).join(" · ");
            return (
              <RecordCard
                key={report.id}
                title={report.report_type}
                badges={<StatusBadge status={report.status} />}
                meta={`${place ? `${place} · ` : ""}Dikirim ${formatDate(
                  report.created_at
                )} · Kedaluwarsa ${formatDate(report.expires_at)}`}
                actions={
                  <form
                    action={moderateUserReport}
                    className="flex flex-wrap items-end gap-2"
                  >
                    <input type="hidden" name="id" value={report.id} />
                    <SelectField
                      label="Ubah status"
                      name="status"
                      id={`status-${report.id}`}
                      defaultValue={report.status}
                      fieldClassName="min-w-40"
                    >
                      {STATUSES.map((status) => (
                        <option key={status} value={status}>
                          {status}
                        </option>
                      ))}
                    </SelectField>
                    <SubmitButton
                      size="sm"
                      aria-label={`Simpan status laporan ${report.report_type}`}
                      loadingLabel="Menyimpan…"
                    >
                      Simpan
                    </SubmitButton>
                  </form>
                }
              >
                <p className="text-ink-muted">{report.description}</p>
              </RecordCard>
            );
          })}
        </RecordList>
      )}
    </div>
  );
}

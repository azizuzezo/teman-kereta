import type { Metadata } from "next";
import Link from "next/link";
import { Badge, StatusBadge } from "@/components/ui/badge";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { FilterTabs, RecordCard, RecordList } from "@/components/ui/record-card";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { CATEGORY_LABELS, formatDate } from "./format";

export const metadata: Metadata = { title: "Laporan aplikasi" };

const FILTERS = ["all", "open", "in_progress", "resolved", "dismissed"] as const;
type Filter = (typeof FILTERS)[number];

const FILTER_LABELS: Record<Filter, string> = {
  all: "Semua",
  open: "Baru",
  in_progress: "Diproses",
  resolved: "Selesai",
  dismissed: "Ditolak",
};

export default async function AppReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  await verifyAdminSession();
  const { status } = await searchParams;
  const filter: Filter = FILTERS.includes(status as Filter)
    ? (status as Filter)
    : "all";

  const supabase = createServiceClient();
  let query = supabase
    .from("app_reports")
    .select(
      "id, category, message, status, email_status, app_version, build_number, device_model, os_version, created_at, has_log"
    )
    .order("created_at", { ascending: false })
    .limit(100);
  if (filter !== "all") {
    query = query.eq("status", filter);
  }
  const { data: reports, error } = await query;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Laporan aplikasi"
        description="Laporan masalah yang dikirim dari menu Bantuan di aplikasi, lengkap dengan info perangkat dan log. Menampilkan 100 laporan terbaru."
      />

      <FilterTabs
        label="Filter status laporan"
        items={FILTERS.map((f) => ({
          href: f === "all" ? "/app-reports" : `/app-reports?status=${f}`,
          label: FILTER_LABELS[f],
          active: filter === f,
        }))}
      />

      {error ? (
        <LoadError what="Daftar laporan aplikasi" error={error} />
      ) : (
        <RecordList
          isEmpty={(reports ?? []).length === 0}
          empty={{
            title: "Belum ada laporan",
            description: "Laporan dari aplikasi akan muncul di sini.",
          }}
        >
          {(reports ?? []).map((report) => (
            <RecordCard
              key={report.id}
              title={
                <Link
                  href={`/app-reports/${report.id}`}
                  className="hover:underline"
                >
                  #{report.id.slice(0, 8).toUpperCase()} ·{" "}
                  {CATEGORY_LABELS[report.category] ?? report.category}
                </Link>
              }
              badges={
                <>
                  <StatusBadge status={report.status} />
                  <Badge tone={report.has_log ? "brand" : "neutral"}>
                    {report.has_log ? "Ada log" : "Tanpa log"}
                  </Badge>
                  {report.email_status !== "sent" && (
                    <StatusBadge status={`email ${report.email_status}`} />
                  )}
                </>
              }
              meta={`${formatDate(report.created_at)} · v${
                report.app_version ?? "?"
              }${report.build_number ? `+${report.build_number}` : ""} · ${
                report.device_model ?? "perangkat tidak diketahui"
              }${report.os_version ? ` · ${report.os_version}` : ""}`}
            >
              <p className="line-clamp-2 text-ink-muted">{report.message}</p>
            </RecordCard>
          ))}
        </RecordList>
      )}
    </div>
  );
}

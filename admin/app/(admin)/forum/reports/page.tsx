import type { Metadata } from "next";
import { StatusBadge } from "@/components/ui/badge";
import { SubmitButton } from "@/components/ui/button";
import { ConfirmButton } from "@/components/ui/confirm-button";
import { PageHeader } from "@/components/ui/page-header";
import { FilterTabs, RecordCard, RecordList } from "@/components/ui/record-card";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { resolveReport } from "../actions";

export const metadata: Metadata = { title: "Laporan forum" };

const FILTERS = ["open", "reviewed", "dismissed", "all"] as const;
type Filter = (typeof FILTERS)[number];

const FILTER_LABELS: Record<Filter, string> = {
  open: "Terbuka",
  reviewed: "Ditinjau",
  dismissed: "Diabaikan",
  all: "Semua",
};

const REASON_LABELS: Record<string, string> = {
  spam: "Spam atau iklan",
  harassment: "Pelecehan / ujaran kebencian",
  inappropriate: "Konten tidak pantas",
  misinformation: "Informasi menyesatkan",
  other: "Lainnya",
};

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

type ReportRow = {
  id: string;
  reason: string;
  details: string | null;
  status: string;
  created_at: string;
  reporter: { display_name: string | null; email: string | null } | null;
  forum_posts: { body: string; status: string } | null;
  forum_comments: { body: string; status: string } | null;
};

export default async function ForumReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  await verifyAdminSession();
  const { status } = await searchParams;
  const filter: Filter = (FILTERS as readonly string[]).includes(status ?? "")
    ? (status as Filter)
    : "open";

  const supabase = createServiceClient();
  let query = supabase
    .from("forum_reports")
    .select(
      "id, reason, details, status, created_at, reporter:users!forum_reports_reporter_id_fkey(display_name, email), forum_posts(body, status), forum_comments(body, status)"
    )
    .order("created_at", { ascending: false })
    .limit(100);

  if (filter !== "all") {
    query = query.eq("status", filter);
  }

  const { data } = await query;
  const reports = (data ?? []) as unknown as ReportRow[];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Laporan forum"
        description={
          <>
            Laporan pengguna atas postingan dan komentar. &ldquo;Tinjau dan
            sembunyikan&rdquo; menyembunyikan konten lalu menutup laporan.
            Konten bisa ditampilkan lagi dari halaman Forum.
          </>
        }
        back={{ href: "/forum", label: "Kembali ke forum" }}
      />

      <FilterTabs
        label="Filter status laporan"
        items={FILTERS.map((f) => ({
          href: `/forum/reports?status=${f}`,
          label: FILTER_LABELS[f],
          active: filter === f,
        }))}
      />

      <RecordList
        isEmpty={reports.length === 0}
        empty={{
          title: "Tidak ada laporan",
          description:
            filter === "open"
              ? "Tidak ada laporan yang menunggu ditinjau."
              : "Tidak ada laporan dengan status ini.",
        }}
      >
        {reports.map((report) => {
          const target = report.forum_posts ?? report.forum_comments;
          const kind = report.forum_posts ? "Postingan" : "Komentar";
          return (
            <RecordCard
              key={report.id}
              title={REASON_LABELS[report.reason] ?? report.reason}
              badges={<StatusBadge status={report.status} />}
              meta={`${kind} · ${formatDate(report.created_at)} · dilaporkan oleh ${
                report.reporter?.display_name ?? "Pengguna"
              }${report.reporter?.email ? ` (${report.reporter.email})` : ""}`}
              actions={
                report.status === "open" ? (
                  <>
                    <ConfirmButton
                      action={resolveReport.bind(null, report.id, "reviewed")}
                      label="Tinjau dan sembunyikan"
                      ariaLabel={`Tinjau dan sembunyikan ${kind.toLowerCase()} yang dilaporkan`}
                      title="Sembunyikan konten yang dilaporkan?"
                      description="Konten disembunyikan dari aplikasi dan laporan ditutup. Kamu bisa menampilkannya lagi dari halaman Forum."
                      confirmLabel="Ya, sembunyikan"
                      triggerVariant="primary"
                      variant="primary"
                    />
                    <form action={resolveReport.bind(null, report.id, "dismissed")}>
                      <SubmitButton
                        variant="secondary"
                        size="sm"
                        aria-label={`Abaikan laporan ${kind.toLowerCase()}`}
                        loadingLabel="Menyimpan…"
                      >
                        Abaikan
                      </SubmitButton>
                    </form>
                  </>
                ) : undefined
              }
            >
              {report.details && (
                <p className="text-ink-muted">
                  Catatan pelapor: {report.details}
                </p>
              )}
              <p className="mt-2 whitespace-pre-wrap rounded-[10px] bg-surface-alt px-3 py-2 text-sm">
                {target
                  ? target.body.length > 300
                    ? `${target.body.slice(0, 300)}…`
                    : target.body
                  : "(konten sudah dihapus)"}
                {target && (
                  <span className="ml-2 text-xs text-ink-muted">
                    [{target.status}]
                  </span>
                )}
              </p>
            </RecordCard>
          );
        })}
      </RecordList>
    </div>
  );
}

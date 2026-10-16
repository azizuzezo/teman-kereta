import type { Metadata } from "next";
import { Badge, type BadgeTone } from "@/components/ui/badge";
import { DataTable } from "@/components/ui/data-table";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";

export const metadata: Metadata = { title: "Log audit" };

const ACTION_TONES: Record<string, BadgeTone> = {
  create: "ok",
  update: "brand",
  delete: "bad",
};

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "medium",
  });
}

export default async function AuditLogPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: entries, error } = await supabase
    .from("audit_log")
    .select("id, action, table_name, record_id, changes, created_at, admin_users(display_name)")
    .order("created_at", { ascending: false })
    .limit(200);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Log audit"
        description="Catatan setiap perubahan yang dibuat lewat panel ini. Tidak bisa diubah atau dihapus dari sini. Menampilkan 200 entri terbaru."
      />

      {error ? (
        <LoadError what="Log audit" error={error} />
      ) : (
        <DataTable
          caption="Log audit perubahan data"
          rows={entries ?? []}
          rowKey={(entry) => entry.id}
          emptyTitle="Belum ada aktivitas"
          emptyDescription="Perubahan data lewat panel ini akan tercatat di sini."
          columns={[
            {
              key: "time",
              header: "Waktu",
              cell: (entry) => (
                <span className="tabular whitespace-nowrap">
                  {formatDate(entry.created_at)}
                </span>
              ),
              className: "align-top",
            },
            {
              key: "action",
              header: "Aksi",
              cell: (entry) => (
                <Badge tone={ACTION_TONES[entry.action] ?? "neutral"}>
                  {entry.action}
                </Badge>
              ),
              className: "align-top",
            },
            {
              key: "table",
              header: "Tabel",
              cell: (entry) => entry.table_name,
              className: "align-top",
            },
            {
              key: "changes",
              header: "Perubahan",
              cell: (entry) =>
                entry.changes ? (
                  <code className="block max-w-xl break-all font-mono text-xs text-ink-muted">
                    {JSON.stringify(entry.changes)}
                  </code>
                ) : (
                  <span className="text-ink-muted">-</span>
                ),
              className: "align-top",
            },
          ]}
        />
      )}
    </div>
  );
}

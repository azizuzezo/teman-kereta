import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { DataTable, RowActions } from "@/components/ui/data-table";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { TRANSPORT_MODES } from "./constants";
import { CreateLineForm } from "./create-form";
import { DeleteLineButton } from "./delete-button";

export const metadata: Metadata = { title: "Lini" };

export default async function LinesPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  const [{ data: lines, error }, { data: operators }] = await Promise.all([
    supabase
      .from("lines")
      .select("id, code, name, transport_mode, color, is_active, operators(name)")
      .order("code"),
    supabase.from("operators").select("id, name").order("name"),
  ]);

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Lini"
        description="Rute yang dioperasikan tiap operator."
      />

      <CreateLineForm operators={operators ?? []} transportModes={TRANSPORT_MODES} />

      {error ? (
        <LoadError what="Daftar lini" error={error} />
      ) : (
        <DataTable
          caption="Daftar lini"
          rows={lines ?? []}
          rowKey={(line) => line.id}
          emptyTitle="Belum ada lini"
          emptyDescription="Tambahkan lini lewat formulir di atas, atau impor dari feed GTFS."
          columns={[
            {
              key: "code",
              header: "Kode",
              cell: (line) => (
                <span className="font-mono text-xs">{line.code}</span>
              ),
            },
            {
              key: "name",
              header: "Nama",
              cell: (line) => <span className="font-semibold">{line.name}</span>,
            },
            {
              key: "operator",
              header: "Operator",
              cell: (line) =>
                (line.operators as unknown as { name: string } | null)?.name ??
                "-",
            },
            {
              key: "mode",
              header: "Moda",
              cell: (line) => <Badge tone="brand">{line.transport_mode}</Badge>,
            },
            {
              key: "color",
              header: "Warna",
              cell: (line) =>
                line.color ? (
                  <span className="inline-flex items-center gap-2">
                    <span
                      aria-hidden="true"
                      className="inline-block size-4 rounded-full border border-line-strong"
                      style={{ backgroundColor: line.color }}
                    />
                    <span className="font-mono text-xs">{line.color}</span>
                  </span>
                ) : (
                  <span className="text-ink-muted">-</span>
                ),
            },
            {
              key: "actions",
              header: "Aksi",
              headerHidden: true,
              align: "right",
              cell: (line) => (
                <RowActions>
                  <ButtonLink
                    href={`/lines/${line.id}/edit`}
                    variant="ghost"
                    size="sm"
                    aria-label={`Edit lini ${line.name}`}
                  >
                    Edit
                  </ButtonLink>
                  <DeleteLineButton lineId={line.id} name={line.name} />
                </RowActions>
              ),
            },
          ]}
        />
      )}
    </div>
  );
}

import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { DataTable, RowActions } from "@/components/ui/data-table";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { CreateStationForm } from "./create-form";
import { DeleteStationButton } from "./delete-button";

export const metadata: Metadata = { title: "Stasiun" };

export default async function StationsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: stations, error } = await supabase
    .from("stations")
    .select("id, code, name, latitude, longitude, wheelchair_accessible")
    .order("code");

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Stasiun"
        description="Stasiun dan halte beserta koordinat dan fasilitasnya."
      />

      <CreateStationForm />

      {error ? (
        <LoadError what="Daftar stasiun" error={error} />
      ) : (
        <DataTable
          caption="Daftar stasiun"
          rows={stations ?? []}
          rowKey={(station) => station.id}
          emptyTitle="Belum ada stasiun"
          emptyDescription="Tambahkan stasiun lewat formulir di atas, atau impor dari feed GTFS."
          columns={[
            {
              key: "code",
              header: "Kode",
              cell: (station) => (
                <span className="font-mono text-xs">{station.code}</span>
              ),
            },
            {
              key: "name",
              header: "Nama",
              cell: (station) => (
                <span className="font-semibold">{station.name}</span>
              ),
            },
            {
              key: "coords",
              header: "Koordinat",
              cell: (station) => (
                <span className="tabular text-ink-muted">
                  {station.latitude.toFixed(5)}, {station.longitude.toFixed(5)}
                </span>
              ),
            },
            {
              key: "wheelchair",
              header: "Akses kursi roda",
              cell: (station) => (
                <Badge tone={station.wheelchair_accessible ? "ok" : "neutral"}>
                  {station.wheelchair_accessible ? "Ya" : "Tidak"}
                </Badge>
              ),
            },
            {
              key: "actions",
              header: "Aksi",
              headerHidden: true,
              align: "right",
              cell: (station) => (
                <RowActions>
                  <ButtonLink
                    href={`/stations/${station.id}/edit`}
                    variant="ghost"
                    size="sm"
                    aria-label={`Edit stasiun ${station.name}`}
                  >
                    Edit
                  </ButtonLink>
                  <DeleteStationButton
                    stationId={station.id}
                    name={station.name}
                  />
                </RowActions>
              ),
            },
          ]}
        />
      )}
    </div>
  );
}

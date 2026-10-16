import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { DataTable, RowActions } from "@/components/ui/data-table";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { CreateNearbyPlaceForm } from "./create-form";
import { DeleteNearbyPlaceButton } from "./delete-button";

export const metadata: Metadata = { title: "Tempat sekitar" };

export default async function NearbyPlacesPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  const [{ data: places, error }, { data: stations }] = await Promise.all([
    supabase
      .from("nearby_places")
      .select(
        "id, name, category, distance_meters, walking_duration_minutes, stations(name, code)"
      )
      .order("name"),
    supabase.from("stations").select("id, name, code").order("name"),
  ]);

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Tempat sekitar"
        description="Tempat di sekitar stasiun, misalnya mal dan kuliner, yang tampil di aplikasi."
      />

      <CreateNearbyPlaceForm stations={stations ?? []} />

      {error ? (
        <LoadError what="Daftar tempat sekitar" error={error} />
      ) : (
        <DataTable
          caption="Daftar tempat sekitar stasiun"
          rows={places ?? []}
          rowKey={(place) => place.id}
          emptyTitle="Belum ada tempat"
          emptyDescription="Tambahkan tempat di sekitar stasiun lewat formulir di atas."
          columns={[
            {
              key: "name",
              header: "Nama",
              cell: (place) => (
                <span className="font-semibold">{place.name}</span>
              ),
            },
            {
              key: "station",
              header: "Stasiun",
              cell: (place) => {
                const station = place.stations as unknown as {
                  name: string;
                  code: string;
                } | null;
                return station ? `${station.name} (${station.code})` : "-";
              },
            },
            {
              key: "category",
              header: "Kategori",
              cell: (place) => <Badge tone="brand">{place.category}</Badge>,
            },
            {
              key: "distance",
              header: "Jarak",
              cell: (place) => (
                <span className="tabular text-ink-muted">
                  {place.distance_meters != null
                    ? `${place.distance_meters} m`
                    : "-"}
                  {place.walking_duration_minutes != null &&
                    ` · ${place.walking_duration_minutes} menit jalan kaki`}
                </span>
              ),
            },
            {
              key: "actions",
              header: "Aksi",
              headerHidden: true,
              align: "right",
              cell: (place) => (
                <RowActions>
                  <ButtonLink
                    href={`/nearby-places/${place.id}/edit`}
                    variant="ghost"
                    size="sm"
                    aria-label={`Edit tempat ${place.name}`}
                  >
                    Edit
                  </ButtonLink>
                  <DeleteNearbyPlaceButton
                    placeId={place.id}
                    name={place.name}
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

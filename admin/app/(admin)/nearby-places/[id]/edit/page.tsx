import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { EditNearbyPlaceForm } from "./edit-form";

export const metadata: Metadata = { title: "Edit tempat" };

export default async function EditNearbyPlacePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await verifyAdminSession();
  const { id } = await params;
  const supabase = createServiceClient();

  const [{ data: place }, { data: stations }] = await Promise.all([
    supabase
      .from("nearby_places")
      .select(
        "id, station_id, name, category, latitude, longitude, distance_meters, walking_duration_minutes, address, description"
      )
      .eq("id", id)
      .maybeSingle(),
    supabase.from("stations").select("id, name, code").order("name"),
  ]);

  if (!place) {
    notFound();
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Edit tempat"
        description={place.name}
        back={{ href: "/nearby-places", label: "Kembali ke daftar tempat" }}
      />

      <EditNearbyPlaceForm place={place} stations={stations ?? []} />
    </div>
  );
}

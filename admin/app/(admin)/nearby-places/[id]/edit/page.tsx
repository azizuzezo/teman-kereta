import { notFound } from "next/navigation";
import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { EditNearbyPlaceForm } from "./edit-form";

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
      <div>
        <Link
          href="/nearby-places"
          className="text-sm text-black/60 hover:underline dark:text-white/60"
        >
          ← Kembali ke daftar destinasi
        </Link>
        <h1 className="mt-2 text-lg font-semibold">Edit destinasi</h1>
      </div>

      <EditNearbyPlaceForm place={place} stations={stations ?? []} />
    </div>
  );
}

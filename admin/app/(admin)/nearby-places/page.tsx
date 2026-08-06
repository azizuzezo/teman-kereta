import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { CreateNearbyPlaceForm } from "./create-form";
import { DeleteNearbyPlaceButton } from "./delete-button";

export default async function NearbyPlacesPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  const [{ data: places }, { data: stations }] = await Promise.all([
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
      <div>
        <h1 className="text-lg font-semibold">Destinasi Sekitar Stasiun</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Tempat menarik di sekitar stasiun (mall, kuliner, dsb.) — PRD §36
          &quot;Kelola destinasi&quot;.
        </p>
      </div>

      <CreateNearbyPlaceForm stations={stations ?? []} />

      <div className="overflow-x-auto rounded-lg border border-black/10 dark:border-white/10">
        <table className="w-full text-sm">
          <thead className="border-b border-black/10 text-left dark:border-white/10">
            <tr>
              <th className="p-3">Nama</th>
              <th className="p-3">Stasiun</th>
              <th className="p-3">Kategori</th>
              <th className="p-3">Jarak</th>
              <th className="p-3" />
            </tr>
          </thead>
          <tbody>
            {(places ?? []).map((place) => {
              const station = place.stations as unknown as {
                name: string;
                code: string;
              } | null;
              return (
                <tr
                  key={place.id}
                  className="border-b border-black/5 last:border-0 dark:border-white/5"
                >
                  <td className="p-3">{place.name}</td>
                  <td className="p-3">
                    {station ? `${station.name} (${station.code})` : "—"}
                  </td>
                  <td className="p-3">{place.category}</td>
                  <td className="p-3 text-xs text-black/60 dark:text-white/60">
                    {place.distance_meters != null
                      ? `${place.distance_meters} m`
                      : "—"}
                    {place.walking_duration_minutes != null &&
                      ` · ${place.walking_duration_minutes} menit jalan kaki`}
                  </td>
                  <td className="p-3 text-right">
                    <div className="flex items-center justify-end gap-3">
                      <Link
                        href={`/nearby-places/${place.id}/edit`}
                        className="text-xs text-black/70 hover:underline dark:text-white/70"
                      >
                        Edit
                      </Link>
                      <DeleteNearbyPlaceButton placeId={place.id} />
                    </div>
                  </td>
                </tr>
              );
            })}
            {(places ?? []).length === 0 && (
              <tr>
                <td
                  colSpan={5}
                  className="p-3 text-center text-black/50 dark:text-white/50"
                >
                  Belum ada destinasi.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { CreateStationForm } from "./create-form";
import { deleteStation } from "./actions";

export default async function StationsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: stations } = await supabase
    .from("stations")
    .select("id, code, name, latitude, longitude, wheelchair_accessible")
    .order("code");

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-lg font-semibold">Stasiun</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Stasiun/halte beserta koordinat dan fasilitas.
        </p>
      </div>

      <CreateStationForm />

      <div className="overflow-x-auto rounded-lg border border-black/10 dark:border-white/10">
        <table className="w-full text-sm">
          <thead className="border-b border-black/10 text-left dark:border-white/10">
            <tr>
              <th className="p-3">Kode</th>
              <th className="p-3">Nama</th>
              <th className="p-3">Koordinat</th>
              <th className="p-3">Akses kursi roda</th>
              <th className="p-3" />
            </tr>
          </thead>
          <tbody>
            {(stations ?? []).map((station) => (
              <tr
                key={station.id}
                className="border-b border-black/5 last:border-0 dark:border-white/5"
              >
                <td className="p-3">{station.code}</td>
                <td className="p-3">{station.name}</td>
                <td className="p-3 text-xs text-black/60 dark:text-white/60">
                  {station.latitude.toFixed(5)}, {station.longitude.toFixed(5)}
                </td>
                <td className="p-3">{station.wheelchair_accessible ? "Ya" : "Tidak"}</td>
                <td className="p-3 text-right">
                  <div className="flex items-center justify-end gap-3">
                    <Link
                      href={`/stations/${station.id}/edit`}
                      className="text-xs text-black/70 hover:underline dark:text-white/70"
                    >
                      Edit
                    </Link>
                    <form action={deleteStation}>
                      <input type="hidden" name="id" value={station.id} />
                      <button
                        type="submit"
                        className="text-xs text-red-600 hover:underline dark:text-red-400"
                      >
                        Hapus
                      </button>
                    </form>
                  </div>
                </td>
              </tr>
            ))}
            {(stations ?? []).length === 0 && (
              <tr>
                <td
                  colSpan={5}
                  className="p-3 text-center text-black/50 dark:text-white/50"
                >
                  Belum ada stasiun.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { GtfsImportForm } from "./import-form";

export default async function GtfsImportPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: operators } = await supabase
    .from("operators")
    .select("id, name")
    .order("name");

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-lg font-semibold">Impor jadwal GTFS</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Impor feed GTFS Schedule (statis) ke tabel referensi nyata
          (operator/jalur/stasiun/trip/jadwal perhentian) — berbeda dari
          importer di aplikasi Flutter, yang hanya menyimpan cache di
          perangkat. Stasiun diselaraskan berdasarkan <code>code</code>{" "}
          (stop_id), jalur berdasarkan kode jalur (route_id) di bawah
          operator yang dipilih.
        </p>
        <p className="mt-2 rounded-md bg-yellow-50 p-3 text-xs text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300">
          <code>trips.service_date</code> adalah tanggal konkret, bukan pola
          berulang — impor ini meratakan calendar.txt/calendar_dates.txt
          menjadi baris trip bertanggal untuk N hari ke depan yang dipilih.
          Belum ada router lintas-transit; hanya trip langsung pada
          <code> trip_id</code> yang sama yang bisa dicari (sama seperti
          keterbatasan <code>local_supabase</code> yang sudah ada).
        </p>
      </div>

      {operators && operators.length > 0 ? (
        <GtfsImportForm operators={operators} />
      ) : (
        <p className="text-sm text-black/60 dark:text-white/60">
          Belum ada operator. Buat operator dulu di halaman{" "}
          <a href="/operators" className="underline">
            Operator
          </a>{" "}
          sebelum mengimpor jadwal.
        </p>
      )}
    </div>
  );
}

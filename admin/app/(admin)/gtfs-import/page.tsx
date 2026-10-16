import type { Metadata } from "next";
import { ButtonLink } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { OperatorIcon } from "@/components/ui/icons";
import { Notice } from "@/components/ui/notice";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { GtfsImportForm } from "./import-form";

export const metadata: Metadata = { title: "Impor GTFS" };

export default async function GtfsImportPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: operators } = await supabase
    .from("operators")
    .select("id, name")
    .order("name");

  return (
    <div className="flex max-w-3xl flex-col gap-6">
      <PageHeader
        title="Impor GTFS"
        description={
          <>
            Impor feed GTFS Schedule (statis) ke tabel referensi: operator,
            lini, stasiun, trip, dan jadwal perhentian. Berbeda dari importer
            di aplikasi Flutter yang hanya menyimpan cache di perangkat.
            Stasiun dicocokkan lewat <code>code</code> (stop_id), lini lewat
            kode lini (route_id) di bawah operator yang dipilih.
          </>
        }
      />
      <Notice tone="warn" title="Tanggal konkret, bukan pola berulang">
        <p>
          <code>trips.service_date</code> berisi tanggal konkret. Impor ini
          meratakan calendar.txt dan calendar_dates.txt menjadi baris trip
          bertanggal untuk sekian hari ke depan yang kamu pilih.
        </p>
        <p>
          Belum ada router lintas transit: hanya trip langsung dengan{" "}
          <code>trip_id</code> yang sama yang bisa dicari, sama seperti
          keterbatasan <code>local_supabase</code> yang sudah ada.
        </p>
      </Notice>

      {operators && operators.length > 0 ? (
        <GtfsImportForm operators={operators} />
      ) : (
        <Card>
          <EmptyState
            title="Belum ada operator"
            description="Buat operator dulu sebelum mengimpor jadwal."
            icon={<OperatorIcon width={24} height={24} />}
            action={<ButtonLink href="/operators">Ke halaman Operator</ButtonLink>}
          />
        </Card>
      )}
    </div>
  );
}

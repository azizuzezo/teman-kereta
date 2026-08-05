import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";

function StatCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-lg border border-black/10 p-4 dark:border-white/10">
      <p className="text-xs text-black/60 dark:text-white/60">{label}</p>
      <p className="mt-1 text-2xl font-semibold">{value}</p>
    </div>
  );
}

function formatTimestamp(value: string | null | undefined) {
  if (!value) return "Belum ada data";
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function DashboardPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  const [
    operators,
    lines,
    stations,
    activeAlerts,
    pendingReports,
    latestVehiclePosition,
    latestTripUpdate,
    latestServiceAlert,
    operatorsBySource,
  ] = await Promise.all([
    supabase.from("operators").select("id", { count: "exact", head: true }),
    supabase.from("lines").select("id", { count: "exact", head: true }),
    supabase.from("stations").select("id", { count: "exact", head: true }),
    supabase
      .from("service_alerts")
      .select("id", { count: "exact", head: true })
      .or("ends_at.is.null,ends_at.gt.now()"),
    supabase
      .from("user_reports")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending"),
    supabase
      .from("vehicle_positions")
      .select("recorded_at")
      .order("recorded_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from("trip_updates")
      .select("updated_at")
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from("service_alerts")
      .select("updated_at")
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase.from("operators").select("data_source_type"),
  ]);

  const sourceCounts = new Map<string, number>();
  for (const row of operatorsBySource.data ?? []) {
    sourceCounts.set(
      row.data_source_type,
      (sourceCounts.get(row.data_source_type) ?? 0) + 1
    );
  }

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-lg font-semibold">Dashboard</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Ringkasan data referensi dan status sinkronisasi terkini.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
        <StatCard label="Operator" value={operators.count ?? 0} />
        <StatCard label="Jalur" value={lines.count ?? 0} />
        <StatCard label="Stasiun" value={stations.count ?? 0} />
        <StatCard label="Gangguan aktif" value={activeAlerts.count ?? 0} />
        <StatCard
          label="Laporan menunggu moderasi"
          value={pendingReports.count ?? 0}
        />
      </div>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Data terakhir diperbarui
        </h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <StatCard
            label="Posisi kendaraan terakhir"
            value={formatTimestamp(latestVehiclePosition.data?.recorded_at)}
          />
          <StatCard
            label="Trip update terakhir"
            value={formatTimestamp(latestTripUpdate.data?.updated_at)}
          />
          <StatCard
            label="Gangguan layanan terakhir"
            value={formatTimestamp(latestServiceAlert.data?.updated_at)}
          />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Status provider (per jenis sumber data operator)
        </h2>
        {sourceCounts.size === 0 ? (
          <p className="text-sm text-black/60 dark:text-white/60">
            Belum ada operator terdaftar.
          </p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {[...sourceCounts.entries()].map(([source, count]) => (
              <span
                key={source}
                className="rounded-full border border-black/10 px-3 py-1 text-xs dark:border-white/10"
              >
                {source}: {count}
              </span>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

import type { Metadata } from "next";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { Section } from "@/components/ui/card";
import {
  AlertIcon,
  LineIcon,
  OperatorIcon,
  ReportIcon,
  StationIcon,
} from "@/components/ui/icons";
import { PageHeader } from "@/components/ui/page-header";
import { StatCard } from "@/components/ui/stat-card";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";

export const metadata: Metadata = { title: "Dashboard" };

const DATA_SOURCE_LABELS: Record<string, string> = {
  official_api: "API resmi",
  gtfs: "GTFS",
  gtfs_realtime: "GTFS realtime",
  open_data: "Data terbuka",
  curated: "Kurasi manual",
  demo: "Demo",
};

function formatTimestamp(value: string | null | undefined) {
  if (!value) return "Belum ada data";
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Asia/Jakarta",
  });
}

export default async function DashboardPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const loadedAt = new Date();

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

  const alertCount = activeAlerts.count ?? 0;
  const pendingCount = pendingReports.count ?? 0;

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Dashboard"
        description={`Ringkasan data referensi dan status sinkronisasi. Dimuat ${formatTimestamp(
          loadedAt.toISOString()
        )} WIB.`}
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <StatCard
          label="Operator"
          value={operators.count ?? 0}
          href="/operators"
          icon={<OperatorIcon />}
        />
        <StatCard
          label="Lini"
          value={lines.count ?? 0}
          href="/lines"
          icon={<LineIcon />}
        />
        <StatCard
          label="Stasiun"
          value={stations.count ?? 0}
          href="/stations"
          icon={<StationIcon />}
        />
        <StatCard
          label="Peringatan layanan aktif"
          value={alertCount}
          href="/service-alerts"
          icon={<AlertIcon />}
          emphasis={alertCount > 0}
        />
        <StatCard
          label="Laporan pengguna menunggu"
          value={pendingCount}
          href="/user-reports"
          icon={<ReportIcon />}
          emphasis={pendingCount > 0}
        />
      </div>

      <Section
        title="Data terakhir diperbarui"
        description="Waktu entri terbaru di tiap tabel, dalam WIB."
      >
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          <StatCard
            small
            label="Posisi kendaraan"
            value={formatTimestamp(latestVehiclePosition.data?.recorded_at)}
          />
          <StatCard
            small
            label="Pembaruan trip"
            value={formatTimestamp(latestTripUpdate.data?.updated_at)}
          />
          <StatCard
            small
            label="Peringatan layanan"
            value={formatTimestamp(latestServiceAlert.data?.updated_at)}
          />
        </div>
      </Section>

      <Section
        title="Sumber data operator"
        description="Jumlah operator menurut jenis sumber datanya."
      >
        {sourceCounts.size === 0 ? (
          <div className="rounded-card border border-line bg-surface">
            <EmptyState
              title="Belum ada operator"
              description="Tambahkan operator di halaman Operator."
              icon={<OperatorIcon width={24} height={24} />}
            />
          </div>
        ) : (
          <ul className="flex flex-wrap gap-2">
            {[...sourceCounts.entries()].map(([source, count]) => (
              <li key={source}>
                <Badge tone="brand" className="tabular text-sm">
                  {DATA_SOURCE_LABELS[source] ?? source}: {count}
                </Badge>
              </li>
            ))}
          </ul>
        )}
      </Section>
    </div>
  );
}

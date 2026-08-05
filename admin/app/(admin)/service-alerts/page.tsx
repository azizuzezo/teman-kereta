import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { CreateServiceAlertForm } from "./create-form";
import { resolveServiceAlert } from "./actions";

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function ServiceAlertsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  const [{ data: alerts }, { data: operators }] = await Promise.all([
    supabase
      .from("service_alerts")
      .select("id, title, description, severity, starts_at, ends_at, operators(name)")
      .order("starts_at", { ascending: false })
      .limit(50),
    supabase.from("operators").select("id, name").order("name"),
  ]);

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h1 className="text-lg font-semibold">Gangguan Layanan</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Pengumuman gangguan/perubahan layanan yang ditampilkan di aplikasi.
        </p>
      </div>

      <CreateServiceAlertForm operators={operators ?? []} />

      <div className="flex flex-col gap-3">
        {(alerts ?? []).map((alert) => {
          const isActive = !alert.ends_at || new Date(alert.ends_at) > new Date();
          return (
            <div
              key={alert.id}
              className="rounded-lg border border-black/10 p-4 dark:border-white/10"
            >
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="font-medium">
                    {alert.title}{" "}
                    <span className="text-xs font-normal text-black/50 dark:text-white/50">
                      ({(alert.operators as unknown as { name: string } | null)?.name ?? "—"} · {alert.severity})
                    </span>
                  </p>
                  <p className="mt-1 text-sm text-black/70 dark:text-white/70">
                    {alert.description}
                  </p>
                  <p className="mt-1 text-xs text-black/50 dark:text-white/50">
                    Mulai {formatDate(alert.starts_at)}
                    {alert.ends_at && ` · Berakhir ${formatDate(alert.ends_at)}`}
                  </p>
                </div>
                {isActive ? (
                  <form action={resolveServiceAlert}>
                    <input type="hidden" name="id" value={alert.id} />
                    <button
                      type="submit"
                      className="shrink-0 rounded-md border border-black/15 px-3 py-1 text-xs dark:border-white/20"
                    >
                      Tandai selesai
                    </button>
                  </form>
                ) : (
                  <span className="shrink-0 rounded-full bg-black/5 px-2 py-0.5 text-xs dark:bg-white/10">
                    Selesai
                  </span>
                )}
              </div>
            </div>
          );
        })}
        {(alerts ?? []).length === 0 && (
          <p className="text-sm text-black/50 dark:text-white/50">
            Belum ada gangguan layanan.
          </p>
        )}
      </div>
    </div>
  );
}

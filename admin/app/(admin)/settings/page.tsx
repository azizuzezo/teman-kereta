import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { updateMaintenanceMode } from "./actions";
import { RemoteConfigForm } from "./remote-config-form";

export default async function SettingsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: rows } = await supabase
    .from("app_config")
    .select("key, value")
    .in("key", ["maintenance_mode", "remote_config"]);

  const maintenanceMode = Boolean(
    rows?.find((r) => r.key === "maintenance_mode")?.value
  );
  const remoteConfig = rows?.find((r) => r.key === "remote_config")?.value ?? {};

  return (
    <div className="flex max-w-2xl flex-col gap-8">
      <div>
        <h1 className="text-lg font-semibold">Pengaturan</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Mode maintenance dan remote configuration (PRD §36).
        </p>
        <p className="mt-2 rounded-md bg-yellow-50 p-3 text-xs text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300">
          Catatan: aplikasi Flutter belum membaca tabel <code>app_config</code>{" "}
          ini — mengubah nilai di bawah tersimpan nyata di database tetapi
          belum berefek ke aplikasi mobile sampai jalur pembacaannya dibangun
          di sisi Flutter.
        </p>
      </div>

      <section className="rounded-lg border border-black/10 p-4 dark:border-white/10">
        <h2 className="mb-2 text-sm font-semibold">Mode maintenance</h2>
        <form action={updateMaintenanceMode} className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              name="maintenance_mode"
              defaultChecked={maintenanceMode}
            />
            Aktifkan mode maintenance
          </label>
          <button
            type="submit"
            className="rounded-md bg-black px-3 py-1.5 text-xs font-medium text-white dark:bg-white dark:text-black"
          >
            Simpan
          </button>
        </form>
      </section>

      <section className="rounded-lg border border-black/10 p-4 dark:border-white/10">
        <h2 className="mb-2 text-sm font-semibold">Remote configuration</h2>
        <RemoteConfigForm value={remoteConfig} />
      </section>
    </div>
  );
}

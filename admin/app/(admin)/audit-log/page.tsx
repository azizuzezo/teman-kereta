import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "medium",
  });
}

export default async function AuditLogPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: entries } = await supabase
    .from("audit_log")
    .select("id, action, table_name, record_id, changes, created_at, admin_users(display_name)")
    .order("created_at", { ascending: false })
    .limit(200);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-lg font-semibold">Audit Log</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Catatan setiap perubahan yang dilakukan lewat admin panel ini —
          tidak bisa diedit atau dihapus dari sini.
        </p>
      </div>

      <div className="overflow-x-auto rounded-lg border border-black/10 dark:border-white/10">
        <table className="w-full text-sm">
          <thead className="border-b border-black/10 text-left dark:border-white/10">
            <tr>
              <th className="p-3">Waktu</th>
              <th className="p-3">Aksi</th>
              <th className="p-3">Tabel</th>
              <th className="p-3">Perubahan</th>
            </tr>
          </thead>
          <tbody>
            {(entries ?? []).map((entry) => (
              <tr
                key={entry.id}
                className="border-b border-black/5 align-top last:border-0 dark:border-white/5"
              >
                <td className="whitespace-nowrap p-3">
                  {formatDate(entry.created_at)}
                </td>
                <td className="p-3">{entry.action}</td>
                <td className="p-3">{entry.table_name}</td>
                <td className="p-3 font-mono text-xs">
                  {entry.changes ? JSON.stringify(entry.changes) : "—"}
                </td>
              </tr>
            ))}
            {(entries ?? []).length === 0 && (
              <tr>
                <td
                  colSpan={4}
                  className="p-3 text-center text-black/50 dark:text-white/50"
                >
                  Belum ada aktivitas.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

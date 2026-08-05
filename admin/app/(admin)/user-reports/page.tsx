import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { moderateUserReport } from "./actions";

const STATUSES = ["pending", "verified", "rejected", "resolved", "expired"];

function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function UserReportsPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();
  const { data: reports } = await supabase
    .from("user_reports")
    .select(
      "id, report_type, description, status, created_at, expires_at, stations(name), lines(name)"
    )
    .order("created_at", { ascending: false })
    .limit(100);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-lg font-semibold">Laporan Pengguna</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Moderasi laporan yang dikirim pengguna dari aplikasi.
        </p>
      </div>

      <div className="flex flex-col gap-3">
        {(reports ?? []).map((report) => (
          <div
            key={report.id}
            className="rounded-lg border border-black/10 p-4 dark:border-white/10"
          >
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="font-medium">
                  {report.report_type}{" "}
                  <span className="text-xs font-normal text-black/50 dark:text-white/50">
                    {(report.stations as unknown as { name: string } | null)?.name &&
                      `· ${(report.stations as unknown as { name: string }).name}`}
                    {(report.lines as unknown as { name: string } | null)?.name &&
                      `· ${(report.lines as unknown as { name: string }).name}`}
                  </span>
                </p>
                <p className="mt-1 text-sm text-black/70 dark:text-white/70">
                  {report.description}
                </p>
                <p className="mt-1 text-xs text-black/50 dark:text-white/50">
                  Dikirim {formatDate(report.created_at)} · Kedaluwarsa{" "}
                  {formatDate(report.expires_at)}
                </p>
              </div>
              <form action={moderateUserReport} className="flex shrink-0 gap-2">
                <input type="hidden" name="id" value={report.id} />
                <select
                  name="status"
                  defaultValue={report.status}
                  className="rounded-md border border-black/15 bg-transparent px-2 py-1 text-xs dark:border-white/20"
                >
                  {STATUSES.map((status) => (
                    <option key={status} value={status}>
                      {status}
                    </option>
                  ))}
                </select>
                <button
                  type="submit"
                  className="rounded-md bg-black px-3 py-1 text-xs font-medium text-white dark:bg-white dark:text-black"
                >
                  Simpan
                </button>
              </form>
            </div>
          </div>
        ))}
        {(reports ?? []).length === 0 && (
          <p className="text-sm text-black/50 dark:text-white/50">
            Belum ada laporan pengguna.
          </p>
        )}
      </div>
    </div>
  );
}

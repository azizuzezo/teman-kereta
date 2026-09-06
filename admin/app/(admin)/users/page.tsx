import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";

function formatDate(value: string | null) {
  if (!value) return "-";
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export default async function UsersPage() {
  await verifyAdminSession();
  const supabase = createServiceClient();

  // Query admin_all_users_view which includes ALL registered users.
  const { data: users } = await supabase
    .from("admin_all_users_view")
    .select("user_id, full_name, email, registered_at, last_sign_in_at")
    .order("registered_at", { ascending: false })
    .limit(200);

  const all = users ?? [];

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-bold">Semua Pengguna Terdaftar</h1>
        <p className="text-sm text-black/60 dark:text-white/60">
          Semua akun yang pernah mendaftar di Teman Kereta.
        </p>
      </div>

      {/* Table */}
      <div className="overflow-x-auto rounded-xl border border-black/10 dark:border-white/10">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-black/10 bg-black/5 dark:border-white/10 dark:bg-white/5">
            <tr>
              <th className="p-3 font-semibold">Nama</th>
              <th className="p-3 font-semibold">Email</th>
              <th className="p-3 font-semibold">Daftar</th>
              <th className="p-3 font-semibold">Login Terakhir</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-black/10 dark:divide-white/10">
            {all.length === 0 ? (
              <tr>
                <td colSpan={4} className="p-6 text-center text-black/50 dark:text-white/50">
                  Belum ada pengguna terdaftar.
                </td>
              </tr>
            ) : (
              all.map((user) => (
                <tr key={user.user_id} className="hover:bg-black/5 dark:hover:bg-white/5">
                  <td className="p-3 font-medium">{user.full_name || "Pengguna Teman Kereta"}</td>
                  <td className="p-3 text-black/70 dark:text-white/70">{user.email || "-"}</td>
                  <td className="p-3 text-xs text-black/50 dark:text-white/50">
                    {formatDate(user.registered_at)}
                  </td>
                  <td className="p-3 text-xs text-black/50 dark:text-white/50">
                    {formatDate(user.last_sign_in_at)}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

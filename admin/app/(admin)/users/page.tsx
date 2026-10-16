import type { Metadata } from "next";
import { DataTable, RowActions } from "@/components/ui/data-table";
import { LoadError } from "@/components/ui/load-error";
import { PageHeader } from "@/components/ui/page-header";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { DeleteUserButton, ResetPasswordButton } from "./user-actions";

export const metadata: Metadata = { title: "Pengguna" };

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
  const { data: users, error } = await supabase
    .from("admin_all_users_view")
    .select("user_id, full_name, email, registered_at, last_sign_in_at")
    .order("registered_at", { ascending: false })
    .limit(200);

  const all = users ?? [];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Pengguna"
        description="Semua akun yang pernah mendaftar di Teman Kereta. Menampilkan 200 akun terbaru."
      />

      {error ? (
        <LoadError what="Daftar pengguna" error={error} />
      ) : (
        <DataTable
          caption="Daftar pengguna terdaftar"
          rows={all}
          rowKey={(user) => user.user_id}
          emptyTitle="Belum ada pengguna terdaftar"
          emptyDescription="Akun baru dari aplikasi akan muncul di sini."
          columns={[
            {
              key: "name",
              header: "Nama",
              cell: (user) => (
                <span className="font-semibold">
                  {user.full_name || "Pengguna Teman Kereta"}
                </span>
              ),
            },
            { key: "email", header: "Email", cell: (user) => user.email || "-" },
            {
              key: "registered",
              header: "Daftar",
              cell: (user) => (
                <span className="tabular text-ink-muted">
                  {formatDate(user.registered_at)}
                </span>
              ),
            },
            {
              key: "last",
              header: "Login terakhir",
              cell: (user) => (
                <span className="tabular text-ink-muted">
                  {formatDate(user.last_sign_in_at)}
                </span>
              ),
            },
            {
              key: "actions",
              header: "Aksi",
              headerHidden: true,
              align: "right",
              cell: (user) => (
                <RowActions>
                  <ResetPasswordButton userId={user.user_id} email={user.email} />
                  <DeleteUserButton userId={user.user_id} email={user.email} />
                </RowActions>
              ),
            },
          ]}
        />
      )}
    </div>
  );
}

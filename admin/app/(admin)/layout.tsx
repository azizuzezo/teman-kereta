import { AppShell } from "@/components/shell/app-shell";
import { verifyAdminSession } from "@/lib/dal";
import { logout } from "./actions";

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await verifyAdminSession();

  return (
    <AppShell email={session.email} logout={logout}>
      {children}
    </AppShell>
  );
}

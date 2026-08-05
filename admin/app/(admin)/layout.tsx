import Link from "next/link";
import { verifyAdminSession } from "@/lib/dal";
import { logout } from "./actions";

const NAV_ITEMS = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/operators", label: "Operator" },
  { href: "/lines", label: "Jalur" },
  { href: "/stations", label: "Stasiun" },
  { href: "/gtfs-import", label: "Impor GTFS" },
  { href: "/nearby-places", label: "Destinasi" },
  { href: "/service-alerts", label: "Gangguan Layanan" },
  { href: "/user-reports", label: "Laporan Pengguna" },
  { href: "/audit-log", label: "Audit Log" },
  { href: "/settings", label: "Pengaturan" },
];

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await verifyAdminSession();

  return (
    <div className="flex min-h-screen">
      <aside className="flex w-56 shrink-0 flex-col border-r border-black/10 p-4 dark:border-white/10">
        <p className="mb-4 text-sm font-semibold">Teman Kereta Admin</p>
        <nav className="flex flex-1 flex-col gap-1">
          {NAV_ITEMS.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded px-2 py-1.5 text-sm hover:bg-black/5 dark:hover:bg-white/10"
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="mt-6 border-t border-black/10 pt-4 text-xs dark:border-white/10">
          <p className="mb-2 truncate text-black/60 dark:text-white/60">
            {session.email}
          </p>
          <form action={logout}>
            <button
              type="submit"
              className="text-red-600 hover:underline dark:text-red-400"
            >
              Keluar
            </button>
          </form>
        </div>
      </aside>
      <main className="flex-1 overflow-auto p-6">{children}</main>
    </div>
  );
}

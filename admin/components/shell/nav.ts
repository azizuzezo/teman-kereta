import type { ComponentType, SVGProps } from "react";
import {
  AlertIcon,
  DashboardIcon,
  FlagIcon,
  ForumIcon,
  ImportIcon,
  LineIcon,
  LogIcon,
  OperatorIcon,
  PlaceIcon,
  ReleaseIcon,
  ReportIcon,
  SettingsIcon,
  StationIcon,
  UsersIcon,
} from "@/components/ui/icons";

export type NavItem = {
  href: string;
  label: string;
  icon: ComponentType<SVGProps<SVGSVGElement>>;
};

export type NavGroup = { label: string; items: NavItem[] };

// Only routes that exist under app/(admin). Add an item here only together with its page.
export const NAV_GROUPS: NavGroup[] = [
  {
    label: "Ringkasan",
    items: [{ href: "/dashboard", label: "Dashboard", icon: DashboardIcon }],
  },
  {
    label: "Data referensi",
    items: [
      { href: "/operators", label: "Operator", icon: OperatorIcon },
      { href: "/lines", label: "Lini", icon: LineIcon },
      { href: "/stations", label: "Stasiun", icon: StationIcon },
      { href: "/nearby-places", label: "Tempat sekitar", icon: PlaceIcon },
    ],
  },
  {
    label: "Operasional",
    items: [
      { href: "/service-alerts", label: "Peringatan layanan", icon: AlertIcon },
      { href: "/gtfs-import", label: "Impor GTFS", icon: ImportIcon },
    ],
  },
  {
    label: "Komunitas",
    items: [
      { href: "/forum", label: "Forum", icon: ForumIcon },
      { href: "/forum/reports", label: "Laporan forum", icon: FlagIcon },
      { href: "/user-reports", label: "Laporan pengguna", icon: ReportIcon },
      { href: "/app-reports", label: "Laporan aplikasi", icon: ReportIcon },
      { href: "/users", label: "Pengguna", icon: UsersIcon },
    ],
  },
  {
    label: "Sistem",
    items: [
      { href: "/releases", label: "Rilis", icon: ReleaseIcon },
      { href: "/settings", label: "Pengaturan", icon: SettingsIcon },
      { href: "/audit-log", label: "Log audit", icon: LogIcon },
    ],
  },
];

/** Longest matching href wins, so /forum/reports does not also light up /forum. */
export function findActive(pathname: string) {
  let best: { group: NavGroup; item: NavItem } | null = null;
  for (const group of NAV_GROUPS) {
    for (const item of group.items) {
      const matches =
        pathname === item.href || pathname.startsWith(`${item.href}/`);
      if (matches && (!best || item.href.length > best.item.href.length)) {
        best = { group, item };
      }
    }
  }
  return best;
}

import type { Metadata } from "next";
import { LogoTile } from "@/components/brand/logo-tile";
import { ButtonLink } from "@/components/ui/button";
import { CheckCircleIcon } from "@/components/ui/icons";
import { ThemeToggle } from "@/components/ui/theme-toggle";

export const metadata: Metadata = {
  title: "Email terkonfirmasi",
  description: "Konfirmasi email berhasil untuk akun Teman Kereta.",
};

export default function ConfirmPage() {
  return (
    <main className="relative grid min-h-dvh place-items-center px-4 py-12">
      <div className="absolute right-4 top-4 sm:right-8 sm:top-6">
        <ThemeToggle />
      </div>
      <div className="flex w-full max-w-md flex-col items-center gap-5 rounded-card border border-line bg-surface p-8 text-center">
        <LogoTile size={56} />
        <span className="grid size-12 place-items-center rounded-control bg-ok-soft text-ok">
          <CheckCircleIcon width={28} height={28} />
        </span>
        <div>
          <h1 className="text-2xl font-extrabold tracking-tight text-ink">
            Email berhasil dikonfirmasi
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-ink-muted">
            Akun Teman Kereta kamu sudah aktif. Buka aplikasi di ponsel untuk
            mulai melihat jadwal dan rute KRL.
          </p>
        </div>
        <div className="flex w-full flex-col gap-2">
          <a
            href="temankereta://login-callback"
            className="inline-flex min-h-11 items-center justify-center rounded-control bg-brand px-4 text-sm font-semibold text-on-brand hover:opacity-90"
          >
            Buka aplikasi Teman Kereta
          </a>
          <ButtonLink href="/login" variant="ghost">
            Masuk ke panel admin (khusus pengelola)
          </ButtonLink>
        </div>
      </div>
    </main>
  );
}

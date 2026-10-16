import type { Metadata } from "next";
import { LogoTile, RouteDots } from "@/components/brand/logo-tile";
import { Notice } from "@/components/ui/notice";
import { ThemeToggle } from "@/components/ui/theme-toggle";
import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "Masuk" };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;

  return (
    <div className="min-h-dvh lg:grid lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)]">
      <aside className="hidden flex-col justify-between bg-hero p-12 text-on-hero lg:flex">
        <LogoTile size={56} />
        <div className="flex items-stretch gap-6">
          <RouteDots className="shrink-0 self-center" />
          <div className="max-w-md">
            <p className="text-4xl font-extrabold leading-tight tracking-tight">
              Panel admin Teman Kereta
            </p>
            <p className="mt-4 text-lg leading-relaxed">
              Kelola stasiun, lini, jadwal, dan laporan komunitas yang dipakai
              aplikasi.
            </p>
          </div>
        </div>
        <p className="text-sm">Khusus pengelola yang terdaftar.</p>
      </aside>

      <main className="relative flex min-h-dvh flex-col justify-center px-4 py-12 sm:px-8">
        <div className="absolute right-4 top-4 sm:right-8 sm:top-6">
          <ThemeToggle />
        </div>
        <div className="mx-auto flex w-full max-w-sm flex-col gap-8">
          <div className="flex flex-col gap-5">
            <LogoTile size={56} className="lg:hidden" />
            <div>
              <h1 className="text-3xl font-extrabold tracking-tight text-ink">
                Masuk
              </h1>
              <p className="mt-1 text-sm text-ink-muted">
                Pakai akun admin untuk mengelola data transit.
              </p>
            </div>
          </div>
          {error === "not_admin" && (
            <div role="alert">
              <Notice tone="bad" title="Akun belum terdaftar sebagai admin">
                <p>
                  Login berhasil, tetapi akun ini tidak ada di daftar akses.
                  Minta admin lain untuk menambahkannya.
                </p>
              </Notice>
            </div>
          )}
          <LoginForm />
        </div>
      </main>
    </div>
  );
}

import { LogoTile } from "@/components/brand/logo-tile";
import { ButtonLink } from "@/components/ui/button";

export default function NotFound() {
  return (
    <main className="grid min-h-dvh place-items-center px-4">
      <div className="flex max-w-md flex-col items-center gap-3 text-center">
        <LogoTile size={56} />
        <p className="tabular mt-2 text-5xl font-extrabold text-brand">404</p>
        <h1 className="text-xl font-extrabold text-ink">
          Halaman tidak ditemukan
        </h1>
        <p className="text-sm text-ink-muted">
          Alamat ini tidak ada di panel admin, atau datanya sudah dihapus.
        </p>
        <ButtonLink href="/dashboard" variant="primary" className="mt-2">
          Ke dashboard
        </ButtonLink>
      </div>
    </main>
  );
}

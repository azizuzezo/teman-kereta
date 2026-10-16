import { Notice } from "./notice";

/**
 * Inline failure state for a list whose query failed. Keeps the page chrome
 * and form usable; the real error goes to the server log, not to the screen.
 */
export function LoadError({
  what,
  error,
}: {
  what: string;
  error: { message: string };
}) {
  console.error(`[admin] gagal memuat ${what}:`, error.message);
  return (
    <div role="alert">
      <Notice tone="bad" title={`${what} gagal dimuat`}>
        <p>Coba muat ulang halaman. Kalau masih gagal, cek log server.</p>
      </Notice>
    </div>
  );
}

"use client";

import { Button, ButtonLink } from "./button";
import { AlertCircleIcon } from "./icons";

/**
 * Generic failure view. Never prints error.message: server errors can carry
 * internals. The digest is shown so the owner can find the log line.
 */
export function ErrorPanel({
  digest,
  onRetry,
  homeHref = "/dashboard",
}: {
  digest?: string;
  onRetry?: () => void;
  homeHref?: string;
}) {
  return (
    <div
      role="alert"
      className="mx-auto flex max-w-md flex-col items-center gap-3 py-16 text-center"
    >
      <span className="grid size-14 place-items-center rounded-control bg-bad-soft text-bad">
        <AlertCircleIcon width={28} height={28} />
      </span>
      <h1 className="text-xl font-extrabold text-ink">Halaman gagal dimuat</h1>
      <p className="text-sm text-ink-muted">
        Terjadi kesalahan di server. Coba muat ulang. Kalau masih gagal, kirim
        kode di bawah ke pengembang.
      </p>
      {digest && (
        <p className="rounded-[10px] bg-surface-alt px-3 py-1 font-mono text-xs text-ink-muted">
          {digest}
        </p>
      )}
      <div className="mt-2 flex flex-wrap justify-center gap-2">
        {onRetry && <Button onClick={onRetry}>Muat ulang</Button>}
        <ButtonLink href={homeHref}>Ke dashboard</ButtonLink>
      </div>
    </div>
  );
}

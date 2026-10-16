import type { ReactNode } from "react";
import { cn } from "./cn";

export type BadgeTone = "neutral" | "brand" | "ok" | "warn" | "bad";

const TONES: Record<BadgeTone, string> = {
  neutral: "bg-surface-alt text-ink",
  brand: "bg-brand-soft text-brand",
  ok: "bg-ok-soft text-ok",
  warn: "bg-warn-soft text-warn",
  bad: "bg-bad-soft text-bad",
};

/** Status chip. Pills are reserved for status; buttons and cards are not pills. */
export function Badge({
  tone = "neutral",
  className,
  children,
}: {
  tone?: BadgeTone;
  className?: string;
  children: ReactNode;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold",
        TONES[tone],
        className
      )}
    >
      {children}
    </span>
  );
}

const STATUS_TONES: Record<string, BadgeTone> = {
  // forum content
  visible: "ok",
  hidden: "warn",
  removed: "bad",
  // forum reports
  open: "warn",
  reviewed: "ok",
  dismissed: "neutral",
  // user reports
  pending: "warn",
  verified: "ok",
  rejected: "bad",
  resolved: "neutral",
  expired: "neutral",
  // app reports
  in_progress: "brand",
  "email pending": "warn",
  "email failed": "bad",
  "email sent": "ok",
  // service alert severity
  info: "brand",
  warning: "warn",
  severe: "bad",
  critical: "bad",
};

export function statusTone(status: string): BadgeTone {
  return STATUS_TONES[status] ?? "neutral";
}

export function StatusBadge({ status }: { status: string }) {
  return <Badge tone={statusTone(status)}>{status}</Badge>;
}

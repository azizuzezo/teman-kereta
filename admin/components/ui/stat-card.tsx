import type { ReactNode } from "react";
import Link from "next/link";
import { cn } from "./cn";

/**
 * Real count or timestamp only. No trend arrows or deltas: the dashboard has
 * no historical series to back them (PRD: no numbers without a source).
 */
export function StatCard({
  label,
  value,
  href,
  hrefLabel,
  icon,
  emphasis = false,
  small = false,
  note,
}: {
  label: string;
  value: ReactNode;
  href?: string;
  hrefLabel?: string;
  icon?: ReactNode;
  emphasis?: boolean;
  small?: boolean;
  note?: string;
}) {
  const body = (
    <>
      <div className="flex items-center justify-between gap-2">
        <p className="text-sm font-semibold text-ink-muted">{label}</p>
        {icon && (
          <span
            className={cn(
              "shrink-0",
              emphasis ? "text-bad" : "text-brand"
            )}
          >
            {icon}
          </span>
        )}
      </div>
      <p
        className={cn(
          "tabular mt-2 font-extrabold tracking-tight text-ink",
          small ? "text-base leading-snug" : "text-3xl"
        )}
      >
        {value}
      </p>
      {note && <p className="mt-1 text-xs text-ink-muted">{note}</p>}
    </>
  );
  const base = "rounded-card border border-line bg-surface p-5";
  if (href) {
    return (
      <Link
        href={href}
        aria-label={hrefLabel ?? `${label}: ${value}`}
        className={cn(base, "block transition-colors hover:bg-surface-alt")}
      >
        {body}
      </Link>
    );
  }
  return <div className={base}>{body}</div>;
}

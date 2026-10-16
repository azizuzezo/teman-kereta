import Link from "next/link";
import type { ReactNode } from "react";
import { EmptyState } from "./empty-state";
import { cn } from "./cn";

/**
 * One moderation or content record (alert, release, post, report): title and
 * badges on top, body text, a muted meta line, and actions on the right
 * (below the content on phones). Used where a row of text matters more than
 * columns.
 */
export function RecordCard({
  title,
  badges,
  meta,
  actions,
  children,
}: {
  title: ReactNode;
  badges?: ReactNode;
  meta?: ReactNode;
  actions?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <li className="rounded-card border border-line bg-surface p-5">
      <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
            <h3 className="min-w-0 break-words text-base font-bold text-ink">
              {title}
            </h3>
            {badges}
          </div>
          {children && (
            <div className="mt-2 break-words text-sm text-ink">{children}</div>
          )}
          {meta && <p className="mt-2 text-xs text-ink-muted">{meta}</p>}
        </div>
        {actions && (
          <div className="flex shrink-0 flex-wrap items-center gap-2">
            {actions}
          </div>
        )}
      </div>
    </li>
  );
}

export function RecordList({
  children,
  empty,
  isEmpty,
  className,
}: {
  children: ReactNode;
  empty: { title: string; description?: ReactNode };
  isEmpty: boolean;
  className?: string;
}) {
  if (isEmpty) {
    return (
      <div className="rounded-card border border-line bg-surface">
        <EmptyState title={empty.title} description={empty.description} />
      </div>
    );
  }
  return <ul className={cn("flex flex-col gap-3", className)}>{children}</ul>;
}

/** Pill-free filter tabs backed by links (state lives in the URL). */
export function FilterTabs({
  items,
  label,
}: {
  items: { href: string; label: string; active: boolean }[];
  label: string;
}) {
  return (
    <nav aria-label={label} className="flex flex-wrap gap-2">
      {items.map((item) => (
        <Link
          key={item.href}
          href={item.href}
          aria-current={item.active ? "page" : undefined}
          className={cn(
            "inline-flex min-h-11 items-center rounded-control border px-4 text-sm font-semibold transition-colors md:min-h-9",
            item.active
              ? "border-brand bg-brand text-on-brand"
              : "border-line-strong bg-surface text-ink hover:bg-surface-alt"
          )}
        >
          {item.label}
        </Link>
      ))}
    </nav>
  );
}

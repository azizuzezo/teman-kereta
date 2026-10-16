import type { ReactNode } from "react";
import { InboxIcon } from "./icons";
import { cn } from "./cn";

export function EmptyState({
  title,
  description,
  action,
  icon,
  className,
}: {
  title: string;
  description?: ReactNode;
  action?: ReactNode;
  icon?: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center gap-2 px-6 py-12 text-center",
        className
      )}
    >
      <span className="mb-1 grid size-12 place-items-center rounded-control bg-brand-soft text-brand">
        {icon ?? <InboxIcon width={24} height={24} />}
      </span>
      <p className="text-base font-bold text-ink">{title}</p>
      {description && (
        <p className="max-w-md text-sm text-ink-muted">{description}</p>
      )}
      {action && <div className="mt-2">{action}</div>}
    </div>
  );
}

import type { ReactNode } from "react";
import { EmptyState } from "./empty-state";
import { cn } from "./cn";

export type Column<T> = {
  key: string;
  header: string;
  cell: (row: T) => ReactNode;
  /** Hide the header text visually (e.g. the row-actions column). */
  headerHidden?: boolean;
  align?: "left" | "right";
  className?: string;
};

/**
 * Table with a sticky header, hairline row separators (no zebra) and a
 * built-in empty state. Scrolls inside its own container so the page itself
 * never scrolls sideways on phones.
 */
export function DataTable<T>({
  caption,
  columns,
  rows,
  rowKey,
  emptyTitle,
  emptyDescription,
  emptyAction,
  maxHeightClass = "max-h-[70vh]",
}: {
  caption: string;
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  emptyTitle: string;
  emptyDescription?: ReactNode;
  emptyAction?: ReactNode;
  maxHeightClass?: string;
}) {
  return (
    <div className="overflow-hidden rounded-card border border-line bg-surface">
      {rows.length === 0 ? (
        <EmptyState
          title={emptyTitle}
          description={emptyDescription}
          action={emptyAction}
        />
      ) : (
        <div className={cn("overflow-auto", maxHeightClass)}>
          <table className="w-full min-w-max border-collapse text-sm">
            <caption className="sr-only">{caption}</caption>
            <thead>
              <tr>
                {columns.map((column) => (
                  <th
                    key={column.key}
                    scope="col"
                    className={cn(
                      "sticky top-0 z-10 whitespace-nowrap border-b border-line bg-surface-alt px-4 py-3 text-xs font-bold text-ink-muted",
                      column.align === "right" ? "text-right" : "text-left"
                    )}
                  >
                    {column.headerHidden ? (
                      <span className="sr-only">{column.header}</span>
                    ) : (
                      column.header
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr
                  key={rowKey(row)}
                  className="border-b border-line align-middle last:border-b-0 hover:bg-surface-alt/60"
                >
                  {columns.map((column) => (
                    <td
                      key={column.key}
                      className={cn(
                        "px-4 py-3 text-ink",
                        column.align === "right" && "text-right",
                        column.className
                      )}
                    >
                      {column.cell(row)}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

/** Wrapper for the group of row action buttons at the end of a row. */
export function RowActions({ children }: { children: ReactNode }) {
  return (
    <div className="flex items-center justify-end gap-1">{children}</div>
  );
}

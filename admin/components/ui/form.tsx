"use client";

import { useState, type ComponentProps, type ReactNode } from "react";
import { AlertCircleIcon, CheckCircleIcon } from "./icons";
import { cn } from "./cn";

/**
 * True after an action finished without an error, until the next submit.
 * Pass the `pending` flag and `error` from useActionState.
 */
export function useSavedFlag(pending: boolean, error: string | undefined) {
  const [wasPending, setWasPending] = useState(pending);
  const [saved, setSaved] = useState(false);
  if (pending !== wasPending) {
    setWasPending(pending);
    setSaved(!pending && !error);
  }
  return saved;
}

export function FormCard({
  title,
  description,
  className,
  children,
  ...rest
}: Omit<ComponentProps<"form">, "title"> & {
  title?: string;
  description?: ReactNode;
}) {
  return (
    <form
      className={cn(
        "flex flex-col gap-5 rounded-card border border-line bg-surface p-5",
        className
      )}
      {...rest}
    >
      {(title || description) && (
        <div className="flex flex-col gap-1">
          {title && (
            <h2 className="text-base font-bold text-ink">{title}</h2>
          )}
          {description && (
            <p className="text-sm text-ink-muted">{description}</p>
          )}
        </div>
      )}
      {children}
    </form>
  );
}

/** Responsive field grid: 1 column on phones, `cols` from the md breakpoint. */
export function FormGrid({
  cols = 2,
  className,
  children,
}: {
  cols?: 2 | 3 | 4;
  className?: string;
  children: ReactNode;
}) {
  const colClass = { 2: "md:grid-cols-2", 3: "md:grid-cols-3", 4: "md:grid-cols-4" }[cols];
  return (
    <div className={cn("grid grid-cols-1 gap-4", colClass, className)}>
      {children}
    </div>
  );
}

/**
 * Always-mounted live region so screen readers announce the result of a
 * server action. Shows an error, or a success note once `saved` is true.
 */
export function FormMessage({
  error,
  saved,
  savedLabel = "Tersimpan.",
  className,
}: {
  error?: string;
  saved?: boolean;
  savedLabel?: string;
  className?: string;
}) {
  return (
    <div aria-live="polite" className={cn("min-w-0 text-sm", className)}>
      {error ? (
        <p className="flex items-start gap-2 font-medium text-bad">
          <AlertCircleIcon className="mt-0.5 shrink-0" width={18} height={18} />
          <span className="min-w-0 break-words">{error}</span>
        </p>
      ) : saved ? (
        <p className="flex items-center gap-2 font-medium text-ok">
          <CheckCircleIcon className="shrink-0" width={18} height={18} />
          {savedLabel}
        </p>
      ) : null}
    </div>
  );
}

export function FormFooter({
  className,
  children,
}: {
  className?: string;
  children: ReactNode;
}) {
  return (
    <div
      className={cn(
        "flex flex-wrap items-center gap-x-4 gap-y-3",
        className
      )}
    >
      {children}
    </div>
  );
}

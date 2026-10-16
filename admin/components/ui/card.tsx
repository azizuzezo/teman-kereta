import type { ReactNode } from "react";
import { cn } from "./cn";

type CardTone = "surface" | "soft" | "warn";

const TONES: Record<CardTone, string> = {
  surface: "border-line bg-surface",
  soft: "border-transparent bg-brand-soft",
  warn: "border-transparent bg-warn-soft",
};

/** Hairline card, no shadow: hierarchy comes from size and tone. */
export function Card({
  tone = "surface",
  className,
  children,
}: {
  tone?: CardTone;
  className?: string;
  children: ReactNode;
}) {
  return (
    <div
      className={cn("rounded-card border p-5", TONES[tone], className)}
    >
      {children}
    </div>
  );
}

export function Section({
  title,
  description,
  actions,
  className,
  children,
}: {
  title: string;
  description?: ReactNode;
  actions?: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  return (
    <section className={cn("flex flex-col gap-3", className)}>
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="min-w-0">
          <h2 className="text-base font-bold text-ink">{title}</h2>
          {description && (
            <p className="text-sm text-ink-muted">{description}</p>
          )}
        </div>
        {actions}
      </div>
      {children}
    </section>
  );
}

import type { ReactNode } from "react";
import { AlertCircleIcon, InfoIcon } from "./icons";
import { cn } from "./cn";

const TONES = {
  info: "bg-brand-soft text-ink",
  warn: "bg-warn-soft text-ink",
  bad: "bg-bad-soft text-ink",
} as const;

const ICON_TONES = {
  info: "text-brand",
  warn: "text-warn",
  bad: "text-bad",
} as const;

/** Callout for facts the admin must know before acting (limits, caveats). */
export function Notice({
  tone = "info",
  title,
  className,
  children,
}: {
  tone?: keyof typeof TONES;
  title?: string;
  className?: string;
  children: ReactNode;
}) {
  const Icon = tone === "info" ? InfoIcon : AlertCircleIcon;
  return (
    <div
      className={cn(
        "flex gap-3 rounded-control p-4 text-sm",
        TONES[tone],
        className
      )}
    >
      <Icon className={cn("mt-0.5 shrink-0", ICON_TONES[tone])} width={20} height={20} />
      <div className="min-w-0 space-y-1">
        {title && <p className="font-bold">{title}</p>}
        <div className="space-y-2 leading-relaxed [&_code]:rounded [&_code]:bg-surface [&_code]:px-1 [&_code]:font-mono [&_code]:text-xs">
          {children}
        </div>
      </div>
    </div>
  );
}

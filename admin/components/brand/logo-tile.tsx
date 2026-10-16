import Image from "next/image";
import tkIcon from "@/public/tk_icon.png";
import tkLogoFull from "@/public/tk_logo_full.png";
import { cn } from "@/components/ui/cn";

/**
 * The logo files have an opaque white background, so they always sit on a
 * rounded white tile and are never placed directly on the page background.
 * `unoptimized`: the PNG is imported statically (served from
 * /_next/static/media), no image-optimizer endpoint is needed on Workers.
 */
export function LogoTile({
  variant = "icon",
  size = 40,
  className,
}: {
  variant?: "icon" | "full";
  size?: number;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex shrink-0 overflow-hidden rounded-control bg-white ring-1 ring-black/10",
        className
      )}
      style={{ width: size, height: size }}
    >
      <Image
        src={variant === "icon" ? tkIcon : tkLogoFull}
        alt="Logo Teman Kereta"
        width={size}
        height={size}
        unoptimized
        priority
        className="size-full object-contain"
      />
    </span>
  );
}

/**
 * Identity motif shared with the mobile app: station dots joined by a route
 * line. Decorative, so hidden from assistive technology.
 */
export function RouteDots({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 12 96"
      width="12"
      height="96"
      aria-hidden="true"
      className={className}
    >
      <line x1="6" y1="6" x2="6" y2="90" stroke="currentColor" strokeWidth="2" />
      <circle cx="6" cy="6" r="5" fill="currentColor" />
      <circle cx="6" cy="48" r="4" fill="none" stroke="currentColor" strokeWidth="2" />
      <circle cx="6" cy="90" r="5" fill="var(--tk-accent)" />
    </svg>
  );
}

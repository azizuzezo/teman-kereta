"use client";

import { useSyncExternalStore } from "react";
import { THEME_STORAGE_KEY } from "@/lib/theme";
import { ContrastIcon } from "./icons";
import { cn } from "./cn";

type Resolved = "light" | "dark";

const listeners = new Set<() => void>();
const MEDIA = "(prefers-color-scheme: dark)";

function subscribe(onChange: () => void) {
  listeners.add(onChange);
  const media = window.matchMedia(MEDIA);
  media.addEventListener("change", onChange);
  return () => {
    listeners.delete(onChange);
    media.removeEventListener("change", onChange);
  };
}

function getSnapshot(): Resolved {
  const explicit = document.documentElement.getAttribute("data-theme");
  if (explicit === "light" || explicit === "dark") return explicit;
  return window.matchMedia(MEDIA).matches ? "dark" : "light";
}

function getServerSnapshot(): Resolved {
  return "light";
}

export function ThemeToggle({ className }: { className?: string }) {
  const resolved = useSyncExternalStore(
    subscribe,
    getSnapshot,
    getServerSnapshot
  );
  const next: Resolved = resolved === "dark" ? "light" : "dark";

  function toggle() {
    document.documentElement.setAttribute("data-theme", next);
    try {
      localStorage.setItem(THEME_STORAGE_KEY, next);
    } catch {
      // Storage can be blocked; the choice then lasts for this page view only.
    }
    listeners.forEach((listener) => listener());
  }

  const label = next === "dark" ? "Pakai tema gelap" : "Pakai tema terang";

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={label}
      title={label}
      suppressHydrationWarning
      className={cn(
        "inline-flex size-11 items-center justify-center rounded-control border border-line-strong bg-surface text-ink transition-colors hover:bg-surface-alt md:size-10",
        className
      )}
    >
      <ContrastIcon />
    </button>
  );
}

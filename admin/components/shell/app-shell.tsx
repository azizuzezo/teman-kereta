"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { LogoTile } from "@/components/brand/logo-tile";
import { SubmitButton } from "@/components/ui/button";
import { CloseIcon, LogoutIcon, MenuIcon } from "@/components/ui/icons";
import { ThemeToggle } from "@/components/ui/theme-toggle";
import { cn } from "@/components/ui/cn";
import { NAV_GROUPS, findActive } from "./nav";

export function AppShell({
  email,
  logout,
  children,
}: {
  email: string | null;
  logout: () => void | Promise<void>;
  children: ReactNode;
}) {
  const pathname = usePathname();
  const active = findActive(pathname);
  const [open, setOpen] = useState(false);
  const menuButtonRef = useRef<HTMLButtonElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!open) return;
    closeButtonRef.current?.focus();
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setOpen(false);
        menuButtonRef.current?.focus();
      }
    }
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [open]);

  return (
    <div className="min-h-dvh lg:grid lg:grid-cols-[17rem_minmax(0,1fr)]">
      <a
        href="#konten"
        className="sr-only z-50 rounded-control bg-brand px-4 py-2 text-sm font-semibold text-on-brand focus:not-sr-only focus:fixed focus:left-4 focus:top-4"
      >
        Lewati ke konten
      </a>

      {open && (
        <button
          type="button"
          aria-label="Tutup menu"
          tabIndex={-1}
          onClick={() => setOpen(false)}
          className="fixed inset-0 z-30 bg-overlay lg:hidden"
        />
      )}

      <aside
        id="menu-utama"
        className={cn(
          "fixed inset-y-0 left-0 z-40 flex w-72 max-w-[85vw] flex-col border-r border-line bg-surface transition-transform duration-200 lg:sticky lg:top-0 lg:z-auto lg:h-dvh lg:w-auto lg:max-w-none lg:translate-x-0",
          open ? "translate-x-0" : "max-lg:invisible max-lg:-translate-x-full"
        )}
      >
        <div className="flex items-center justify-between gap-3 px-5 py-4">
          <Link
            href="/dashboard"
            onClick={() => setOpen(false)}
            className="flex min-h-11 items-center gap-3"
          >
            <LogoTile size={40} />
            <span className="leading-tight">
              <span className="block text-sm font-extrabold text-ink">
                Teman Kereta
              </span>
              <span className="block text-xs font-semibold text-ink-muted">
                Panel admin
              </span>
            </span>
          </Link>
          <button
            ref={closeButtonRef}
            type="button"
            aria-label="Tutup menu"
            onClick={() => {
              setOpen(false);
              menuButtonRef.current?.focus();
            }}
            className="inline-flex size-11 items-center justify-center rounded-control text-ink hover:bg-surface-alt lg:hidden"
          >
            <CloseIcon />
          </button>
        </div>

        <nav
          aria-label="Menu utama"
          className="flex-1 overflow-y-auto px-3 pb-4"
        >
          {NAV_GROUPS.map((group) => (
            <div key={group.label} className="mt-4 first:mt-0">
              <p className="px-3 pb-1 text-xs font-bold text-ink-muted">
                {group.label}
              </p>
              <ul className="flex flex-col gap-0.5">
                {group.items.map((item) => {
                  const isActive = active?.item.href === item.href;
                  return (
                    <li key={item.href}>
                      <Link
                        href={item.href}
                        aria-current={isActive ? "page" : undefined}
                        onClick={() => setOpen(false)}
                        className={cn(
                          "flex min-h-11 items-center gap-3 rounded-control px-3 text-sm font-semibold transition-colors",
                          isActive
                            ? "bg-brand-soft text-brand"
                            : "text-ink hover:bg-surface-alt"
                        )}
                      >
                        <item.icon className="shrink-0" />
                        <span className="min-w-0 truncate">{item.label}</span>
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          ))}
        </nav>

        {/* Email + sign-out live in the header from md up; in the drawer on phones. */}
        <div className="border-t border-line p-4 md:hidden">
          <p className="mb-2 truncate text-xs text-ink-muted">{email}</p>
          <form action={logout}>
            <SubmitButton
              variant="secondary"
              className="w-full"
              loadingLabel="Keluar…"
            >
              <LogoutIcon width={18} height={18} />
              Keluar
            </SubmitButton>
          </form>
        </div>
      </aside>

      <div className="min-w-0">
        <header className="sticky top-0 z-20 flex min-h-16 items-center gap-3 border-b border-line bg-surface px-4 md:px-8">
          <button
            ref={menuButtonRef}
            type="button"
            aria-label="Buka menu"
            aria-expanded={open}
            aria-controls="menu-utama"
            onClick={() => setOpen(true)}
            className="inline-flex size-11 shrink-0 items-center justify-center rounded-control border border-line-strong text-ink hover:bg-surface-alt lg:hidden"
          >
            <MenuIcon />
          </button>
          <div className="min-w-0 flex-1 leading-tight">
            {active && (
              <p className="truncate text-xs font-semibold text-ink-muted">
                {active.group.label}
              </p>
            )}
            <p className="truncate text-base font-bold text-ink">
              {active?.item.label ?? "Panel admin"}
            </p>
          </div>
          <p
            className="hidden max-w-60 truncate text-sm text-ink-muted md:block"
            title={email ?? undefined}
          >
            {email}
          </p>
          <ThemeToggle />
          <form action={logout} className="hidden md:block">
            <SubmitButton
              variant="secondary"
              size="sm"
              loadingLabel="Keluar…"
            >
              <LogoutIcon width={18} height={18} />
              Keluar
            </SubmitButton>
          </form>
        </header>

        <main id="konten" tabIndex={-1} className="mx-auto w-full max-w-6xl px-4 py-6 md:px-8 md:py-8">
          {children}
        </main>
      </div>
    </div>
  );
}

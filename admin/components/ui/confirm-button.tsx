"use client";

import { useRef, type ReactNode } from "react";
import { Button, type ButtonVariant } from "./button";

/**
 * Destructive actions go through a native <dialog> (focus trap and Escape
 * come from the platform). The dialog holds its own <form>, so it works with
 * a plain server action, a bound action, or the `formAction` returned by
 * useActionState. Hidden fields are passed as `fields`.
 */
export function ConfirmButton({
  action,
  fields,
  label,
  ariaLabel,
  title,
  description,
  confirmLabel,
  variant = "danger",
  triggerVariant = "ghost",
  loading = false,
  loadingLabel,
}: {
  action: (formData: FormData) => void | Promise<void>;
  fields?: Record<string, string>;
  /** Text on the trigger button. */
  label: ReactNode;
  /** Accessible name for the trigger, naming the row (e.g. "Hapus Stasiun Bogor"). */
  ariaLabel: string;
  title: string;
  description?: ReactNode;
  confirmLabel: string;
  variant?: ButtonVariant;
  triggerVariant?: ButtonVariant;
  loading?: boolean;
  loadingLabel?: ReactNode;
}) {
  const dialogRef = useRef<HTMLDialogElement>(null);

  return (
    <>
      <Button
        variant={triggerVariant}
        size="sm"
        aria-label={ariaLabel}
        loading={loading}
        loadingLabel={loadingLabel}
        className={triggerVariant === "ghost" ? "text-bad hover:bg-bad-soft" : undefined}
        onClick={() => dialogRef.current?.showModal()}
      >
        {label}
      </Button>
      <dialog
        ref={dialogRef}
        aria-label={title}
        className="m-auto w-[min(92vw,26rem)] rounded-card border border-line bg-surface p-0 text-ink shadow-xl"
        onClick={(event) => {
          // Click on the backdrop (the dialog element itself) closes it.
          if (event.target === dialogRef.current) dialogRef.current?.close();
        }}
      >
        <form
          action={action}
          onSubmit={() => dialogRef.current?.close()}
          className="flex flex-col gap-4 p-6"
        >
          {fields &&
            Object.entries(fields).map(([name, value]) => (
              <input key={name} type="hidden" name={name} value={value} />
            ))}
          <h2 className="text-lg font-bold">{title}</h2>
          {description && (
            <p className="text-sm text-ink-muted">{description}</p>
          )}
          <div className="flex flex-wrap justify-end gap-2">
            <Button
              variant="secondary"
              onClick={() => dialogRef.current?.close()}
              autoFocus
            >
              Batal
            </Button>
            <Button type="submit" variant={variant}>
              {confirmLabel}
            </Button>
          </div>
        </form>
      </dialog>
    </>
  );
}

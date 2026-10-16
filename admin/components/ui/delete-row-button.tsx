"use client";

import { useActionState } from "react";
import { ConfirmButton } from "./confirm-button";
import { FormMessage } from "./form";

type DeleteState = { error?: string } | undefined;

/**
 * "Hapus" button for a table row: confirmation dialog first, then the
 * existing delete server action. Blocking reasons returned by the action
 * (e.g. "still has 3 lines") are shown under the button.
 */
export function DeleteRowButton({
  action,
  id,
  entityLabel,
  consequence,
}: {
  action: (
    prevState: DeleteState,
    formData: FormData
  ) => Promise<DeleteState>;
  id: string;
  /** e.g. `operator "KAI Commuter"`, used in the dialog and accessible name. */
  entityLabel: string;
  consequence?: string;
}) {
  const [state, formAction, pending] = useActionState(action, undefined);

  return (
    <div className="flex flex-col items-end gap-1">
      <ConfirmButton
        action={formAction}
        fields={{ id }}
        label="Hapus"
        ariaLabel={`Hapus ${entityLabel}`}
        title={`Hapus ${entityLabel}?`}
        description={
          consequence ?? "Data yang dihapus tidak bisa dikembalikan."
        }
        confirmLabel="Ya, hapus"
        loading={pending}
        loadingLabel="Menghapus…"
      />
      <FormMessage
        error={state?.error}
        className="max-w-64 text-right text-xs"
      />
    </div>
  );
}

"use client";

import { useActionState } from "react";
import { deleteOperator, type DeleteOperatorState } from "./actions";

const initialState: DeleteOperatorState = undefined;

export function DeleteOperatorButton({ operatorId }: { operatorId: string }) {
  const [state, formAction, pending] = useActionState(
    deleteOperator,
    initialState
  );

  return (
    <form action={formAction} className="flex flex-col items-end gap-1">
      <input type="hidden" name="id" value={operatorId} />
      <button
        type="submit"
        disabled={pending}
        className="text-xs text-red-600 hover:underline disabled:opacity-60 dark:text-red-400"
      >
        {pending ? "Menghapus…" : "Hapus"}
      </button>
      {state?.error && (
        <p className="max-w-56 text-right text-xs text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}

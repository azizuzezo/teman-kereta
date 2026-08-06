"use client";

import { useActionState } from "react";
import { deleteNearbyPlace, type DeleteNearbyPlaceState } from "./actions";

const initialState: DeleteNearbyPlaceState = undefined;

export function DeleteNearbyPlaceButton({ placeId }: { placeId: string }) {
  const [state, formAction, pending] = useActionState(
    deleteNearbyPlace,
    initialState
  );

  return (
    <form action={formAction} className="flex flex-col items-end gap-1">
      <input type="hidden" name="id" value={placeId} />
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

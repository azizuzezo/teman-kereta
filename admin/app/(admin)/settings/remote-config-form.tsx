"use client";

import { useActionState } from "react";
import { updateRemoteConfig, type SettingsFormState } from "./actions";

const initialState: SettingsFormState = undefined;

export function RemoteConfigForm({ value }: { value: unknown }) {
  const [state, formAction, pending] = useActionState(
    updateRemoteConfig,
    initialState
  );

  return (
    <form action={formAction} className="flex flex-col gap-2">
      <textarea
        name="remote_config"
        defaultValue={JSON.stringify(value, null, 2)}
        rows={8}
        className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 font-mono text-xs dark:border-white/20"
      />
      <button
        type="submit"
        disabled={pending}
        className="w-fit rounded-md bg-black px-4 py-1.5 text-sm font-medium text-white disabled:opacity-60 dark:bg-white dark:text-black"
      >
        {pending ? "Menyimpan…" : "Simpan remote config"}
      </button>
      {state?.error && (
        <p className="text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}

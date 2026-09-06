"use client";

import { useActionState } from "react";
import { createRelease, type ReleaseFormState } from "./actions";

const initialState: ReleaseFormState = undefined;

export function CreateReleaseForm() {
  const [state, formAction, pending] = useActionState(
    createRelease,
    initialState
  );

  return (
    <form
      action={formAction}
      className="flex flex-col gap-3 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <div className="flex flex-wrap gap-3">
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="version_code">
            Version code
          </label>
          <input
            id="version_code"
            name="version_code"
            type="number"
            min={1}
            step={1}
            required
            className="w-32 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="version_name">
            Version name
          </label>
          <input
            id="version_name"
            name="version_name"
            placeholder="1.2.0"
            required
            className="w-32 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
        <div className="flex flex-col gap-1">
          <label
            className="text-xs font-medium"
            htmlFor="min_supported_version_code"
          >
            Minimum versi didukung (opsional)
          </label>
          <input
            id="min_supported_version_code"
            name="min_supported_version_code"
            type="number"
            min={1}
            step={1}
            className="w-32 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
        <div className="flex flex-1 flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="apk">
            Berkas APK
          </label>
          <input
            id="apk"
            name="apk"
            type="file"
            accept=".apk,application/vnd.android.package-archive"
            required
            className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm file:mr-2 file:rounded file:border-0 file:bg-black/5 file:px-2 file:py-1 file:text-xs dark:border-white/20 dark:file:bg-white/10"
          />
        </div>
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="changelog">
          Changelog
        </label>
        <textarea
          id="changelog"
          name="changelog"
          rows={2}
          placeholder="Apa yang berubah pada rilis ini?"
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <button
        type="submit"
        disabled={pending}
        className="w-fit rounded-md bg-black px-4 py-1.5 text-sm font-medium text-white disabled:opacity-60 dark:bg-white dark:text-black"
      >
        {pending ? "Mengunggah…" : "Terbitkan rilis"}
      </button>
      {state?.error && (
        <p className="text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}

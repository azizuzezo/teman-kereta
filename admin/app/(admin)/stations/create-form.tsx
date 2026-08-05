"use client";

import { useActionState } from "react";
import { createStation, type StationFormState } from "./actions";

const initialState: StationFormState = undefined;

export function CreateStationForm() {
  const [state, formAction, pending] = useActionState(
    createStation,
    initialState
  );

  return (
    <form
      action={formAction}
      className="flex flex-wrap items-end gap-3 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="code">
          Kode
        </label>
        <input
          id="code"
          name="code"
          required
          placeholder="DEMO-BOO"
          className="w-32 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="name">
          Nama stasiun
        </label>
        <input
          id="name"
          name="name"
          required
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="latitude">
          Latitude
        </label>
        <input
          id="latitude"
          name="latitude"
          type="number"
          step="any"
          required
          className="w-32 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="longitude">
          Longitude
        </label>
        <input
          id="longitude"
          name="longitude"
          type="number"
          step="any"
          required
          className="w-32 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" name="wheelchair_accessible" />
        Akses kursi roda
      </label>
      <button
        type="submit"
        disabled={pending}
        className="rounded-md bg-black px-4 py-1.5 text-sm font-medium text-white disabled:opacity-60 dark:bg-white dark:text-black"
      >
        {pending ? "Menyimpan…" : "Tambah stasiun"}
      </button>
      {state?.error && (
        <p className="w-full text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}

"use client";

import { useActionState } from "react";
import { createLine, type LineFormState } from "./actions";

const initialState: LineFormState = undefined;

export function CreateLineForm({
  operators,
  transportModes,
}: {
  operators: { id: string; name: string }[];
  transportModes: readonly string[];
}) {
  const [state, formAction, pending] = useActionState(createLine, initialState);

  return (
    <form
      action={formAction}
      className="flex flex-wrap items-end gap-3 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="operator_id">
          Operator
        </label>
        <select
          id="operator_id"
          name="operator_id"
          required
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        >
          <option value="">Pilih operator</option>
          {operators.map((operator) => (
            <option key={operator.id} value={operator.id}>
              {operator.name}
            </option>
          ))}
        </select>
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="code">
          Kode
        </label>
        <input
          id="code"
          name="code"
          required
          placeholder="DEMO-KRL"
          className="w-28 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="name">
          Nama jalur
        </label>
        <input
          id="name"
          name="name"
          required
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="transport_mode">
          Moda
        </label>
        <select
          id="transport_mode"
          name="transport_mode"
          defaultValue={transportModes[0]}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        >
          {transportModes.map((mode) => (
            <option key={mode} value={mode}>
              {mode}
            </option>
          ))}
        </select>
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="color">
          Warna
        </label>
        <input
          id="color"
          name="color"
          placeholder="#147D64"
          className="w-24 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="text_color">
          Warna teks
        </label>
        <input
          id="text_color"
          name="text_color"
          placeholder="#FFFFFF"
          className="w-24 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <button
        type="submit"
        disabled={pending}
        className="rounded-md bg-black px-4 py-1.5 text-sm font-medium text-white disabled:opacity-60 dark:bg-white dark:text-black"
      >
        {pending ? "Menyimpan…" : "Tambah jalur"}
      </button>
      {state?.error && (
        <p className="w-full text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}

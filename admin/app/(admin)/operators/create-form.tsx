"use client";

import { useActionState } from "react";
import { createOperator, type OperatorFormState } from "./actions";

const initialState: OperatorFormState = undefined;

export function CreateOperatorForm({
  operatorTypes,
  dataSourceTypes,
}: {
  operatorTypes: readonly string[];
  dataSourceTypes: readonly string[];
}) {
  const [state, formAction, pending] = useActionState(
    createOperator,
    initialState
  );

  return (
    <form
      action={formAction}
      className="flex flex-wrap items-end gap-3 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="name">
          Nama operator
        </label>
        <input
          id="name"
          name="name"
          required
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="operator_type">
          Jenis
        </label>
        <select
          id="operator_type"
          name="operator_type"
          defaultValue={operatorTypes[0]}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        >
          {operatorTypes.map((type) => (
            <option key={type} value={type}>
              {type}
            </option>
          ))}
        </select>
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="data_source_type">
          Sumber data
        </label>
        <select
          id="data_source_type"
          name="data_source_type"
          defaultValue={dataSourceTypes[0]}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        >
          {dataSourceTypes.map((type) => (
            <option key={type} value={type}>
              {type}
            </option>
          ))}
        </select>
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="website">
          Website (opsional)
        </label>
        <input
          id="website"
          name="website"
          type="url"
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <button
        type="submit"
        disabled={pending}
        className="rounded-md bg-black px-4 py-1.5 text-sm font-medium text-white disabled:opacity-60 dark:bg-white dark:text-black"
      >
        {pending ? "Menyimpan…" : "Tambah operator"}
      </button>
      {state?.error && (
        <p className="w-full text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}

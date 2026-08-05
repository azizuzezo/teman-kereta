"use client";

import { useActionState } from "react";
import { updateOperator, type OperatorFormState } from "../../actions";

const initialState: OperatorFormState = undefined;

export function EditOperatorForm({
  operator,
  operatorTypes,
  dataSourceTypes,
}: {
  operator: {
    id: string;
    name: string;
    operator_type: string;
    data_source_type: string;
    website: string | null;
  };
  operatorTypes: readonly string[];
  dataSourceTypes: readonly string[];
}) {
  const [state, formAction, pending] = useActionState(
    updateOperator,
    initialState
  );

  return (
    <form
      action={formAction}
      className="flex max-w-md flex-col gap-4 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <input type="hidden" name="id" value={operator.id} />
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="name">
          Nama operator
        </label>
        <input
          id="name"
          name="name"
          required
          defaultValue={operator.name}
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
          defaultValue={operator.operator_type}
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
          defaultValue={operator.data_source_type}
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
          defaultValue={operator.website ?? ""}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <button
        type="submit"
        disabled={pending}
        className="w-fit rounded-md bg-black px-4 py-1.5 text-sm font-medium text-white disabled:opacity-60 dark:bg-white dark:text-black"
      >
        {pending ? "Menyimpan…" : "Simpan perubahan"}
      </button>
      {state?.error && (
        <p className="text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}

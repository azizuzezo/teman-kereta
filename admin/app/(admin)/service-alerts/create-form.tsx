"use client";

import { useActionState } from "react";
import { createServiceAlert, type ServiceAlertFormState } from "./actions";

const initialState: ServiceAlertFormState = undefined;
const SEVERITIES = ["info", "warning", "severe", "critical"];

export function CreateServiceAlertForm({
  operators,
}: {
  operators: { id: string; name: string }[];
}) {
  const [state, formAction, pending] = useActionState(
    createServiceAlert,
    initialState
  );

  return (
    <form
      action={formAction}
      className="flex flex-col gap-3 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <div className="flex flex-wrap gap-3">
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
          <label className="text-xs font-medium" htmlFor="severity">
            Tingkat keparahan
          </label>
          <select
            id="severity"
            name="severity"
            defaultValue="info"
            className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          >
            {SEVERITIES.map((severity) => (
              <option key={severity} value={severity}>
                {severity}
              </option>
            ))}
          </select>
        </div>
        <div className="flex flex-1 flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="title">
            Judul
          </label>
          <input
            id="title"
            name="title"
            required
            className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="description">
          Deskripsi
        </label>
        <textarea
          id="description"
          name="description"
          required
          rows={2}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <button
        type="submit"
        disabled={pending}
        className="w-fit rounded-md bg-black px-4 py-1.5 text-sm font-medium text-white disabled:opacity-60 dark:bg-white dark:text-black"
      >
        {pending ? "Menyimpan…" : "Terbitkan gangguan"}
      </button>
      {state?.error && (
        <p className="text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}

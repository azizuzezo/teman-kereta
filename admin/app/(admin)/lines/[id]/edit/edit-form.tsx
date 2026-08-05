"use client";

import { useActionState } from "react";
import { updateLine, type LineFormState } from "../../actions";

const initialState: LineFormState = undefined;

export function EditLineForm({
  line,
  operators,
  transportModes,
}: {
  line: {
    id: string;
    operator_id: string;
    code: string;
    name: string;
    transport_mode: string;
    color: string | null;
    text_color: string | null;
  };
  operators: { id: string; name: string }[];
  transportModes: readonly string[];
}) {
  const [state, formAction, pending] = useActionState(updateLine, initialState);

  return (
    <form
      action={formAction}
      className="flex max-w-md flex-col gap-4 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <input type="hidden" name="id" value={line.id} />
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="operator_id">
          Operator
        </label>
        <select
          id="operator_id"
          name="operator_id"
          defaultValue={line.operator_id}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        >
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
          defaultValue={line.code}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
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
          defaultValue={line.name}
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
          defaultValue={line.transport_mode}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        >
          {transportModes.map((mode) => (
            <option key={mode} value={mode}>
              {mode}
            </option>
          ))}
        </select>
      </div>
      <div className="flex gap-3">
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="color">
            Warna
          </label>
          <input
            id="color"
            name="color"
            defaultValue={line.color ?? ""}
            placeholder="#147D64"
            className="w-28 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="text_color">
            Warna teks
          </label>
          <input
            id="text_color"
            name="text_color"
            defaultValue={line.text_color ?? ""}
            placeholder="#FFFFFF"
            className="w-28 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
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

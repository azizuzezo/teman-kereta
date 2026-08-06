"use client";

import { useActionState } from "react";
import { importGtfs, type GtfsImportState } from "./actions";

const initialState: GtfsImportState = undefined;

export function GtfsImportForm({
  operators,
}: {
  operators: { id: string; name: string }[];
}) {
  const [state, formAction, pending] = useActionState(importGtfs, initialState);

  return (
    <form
      action={formAction}
      className="flex flex-col gap-4 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="operator_id">
          Operator (jalur akan dikaitkan ke operator ini)
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
        <label className="text-xs font-medium" htmlFor="file">
          Berkas GTFS (.zip)
        </label>
        <input
          id="file"
          name="file"
          type="file"
          accept=".zip"
          required
          className="text-sm"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="window_days">
          Jumlah hari ke depan yang diimpor
        </label>
        <input
          id="window_days"
          name="window_days"
          type="number"
          min={1}
          max={30}
          defaultValue={1}
          required
          className="w-24 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
        <p className="text-xs text-black/50 dark:text-white/50">
          calendar.txt/calendar_dates.txt tidak berulang di skema ini —
          setiap hari yang dipilih menjadi baris trip nyata bertanggal.
          Jumlah besar × banyak trip bisa menghasilkan banyak baris.
        </p>
        <p className="text-xs font-medium text-amber-700 dark:text-amber-400">
          Untuk feed KRL asli (≈86 stasiun, ≈984 trip), 1 hari saja
          menghasilkan ±16 ribu baris jadwal — lebih dari itu berisiko
          melebihi batas waktu/memori satu request Cloudflare Workers dan
          gagal di tengah jalan (halaman ini akan minta reload). Untuk impor
          lebih dari beberapa hari sekaligus, jalankan dari terminal:{" "}
          <code className="rounded bg-black/5 px-1 dark:bg-white/10">
            npm run import-gtfs -- &lt;path-zip&gt; &lt;operator-id&gt;{" "}
            &lt;jumlah-hari&gt;
          </code>{" "}
          — skrip yang sama yang dipakai untuk mengisi data asli saat ini,
          tidak terikat batas satu request web.
        </p>
      </div>
      <button
        type="submit"
        disabled={pending}
        className="w-fit rounded-md bg-black px-4 py-1.5 text-sm font-medium text-white disabled:opacity-60 dark:bg-white dark:text-black"
      >
        {pending ? "Mengimpor… (bisa beberapa puluh detik)" : "Impor GTFS"}
      </button>
      {state && "error" in state && (
        <p className="text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
      {state && "summary" in state && (
        <div className="rounded-md bg-green-50 p-3 text-sm text-green-800 dark:bg-green-900/30 dark:text-green-300">
          <p className="font-medium">Impor berhasil.</p>
          <p>
            {state.summary.stopCount} stasiun, {state.summary.routeCount}{" "}
            jalur, {state.summary.tripCount} pola trip dari feed →{" "}
            {state.summary.tripInstancesImported} baris trip bertanggal dan{" "}
            {state.summary.stopTimeRowsImported} baris jadwal perhentian
            untuk {state.summary.serviceDaysExpanded} hari ke depan.
          </p>
        </div>
      )}
    </form>
  );
}

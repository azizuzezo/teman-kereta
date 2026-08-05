"use client";

import { useActionState } from "react";
import { updateStation, type StationFormState } from "../../actions";

const initialState: StationFormState = undefined;

export function EditStationForm({
  station,
}: {
  station: {
    id: string;
    code: string;
    name: string;
    latitude: number;
    longitude: number;
    wheelchair_accessible: boolean | null;
    facilities: unknown;
  };
}) {
  const [state, formAction, pending] = useActionState(
    updateStation,
    initialState
  );

  return (
    <form
      action={formAction}
      className="flex max-w-md flex-col gap-4 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <input type="hidden" name="id" value={station.id} />
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="code">
          Kode
        </label>
        <input
          id="code"
          name="code"
          required
          defaultValue={station.code}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
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
          defaultValue={station.name}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <div className="flex gap-3">
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
            defaultValue={station.latitude}
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
            defaultValue={station.longitude}
            className="w-32 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
      </div>
      <label className="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          name="wheelchair_accessible"
          defaultChecked={station.wheelchair_accessible ?? false}
        />
        Akses kursi roda
      </label>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="facilities">
          Fasilitas (JSON)
        </label>
        <textarea
          id="facilities"
          name="facilities"
          rows={4}
          defaultValue={JSON.stringify(station.facilities ?? {}, null, 2)}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 font-mono text-xs dark:border-white/20"
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

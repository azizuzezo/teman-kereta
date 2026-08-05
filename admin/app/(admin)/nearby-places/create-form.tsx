"use client";

import { useActionState } from "react";
import { createNearbyPlace, type NearbyPlaceFormState } from "./actions";

const initialState: NearbyPlaceFormState = undefined;

export function CreateNearbyPlaceForm({
  stations,
}: {
  stations: { id: string; name: string; code: string }[];
}) {
  const [state, formAction, pending] = useActionState(
    createNearbyPlace,
    initialState
  );

  return (
    <form
      action={formAction}
      className="flex flex-col gap-3 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <div className="flex flex-wrap gap-3">
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="station_id">
            Stasiun
          </label>
          <select
            id="station_id"
            name="station_id"
            required
            className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          >
            <option value="">Pilih stasiun</option>
            {stations.map((station) => (
              <option key={station.id} value={station.id}>
                {station.name} ({station.code})
              </option>
            ))}
          </select>
        </div>
        <div className="flex flex-1 flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="name">
            Nama tempat
          </label>
          <input
            id="name"
            name="name"
            required
            className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="category">
            Kategori
          </label>
          <input
            id="category"
            name="category"
            required
            placeholder="mall, kuliner, dst."
            className="w-40 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
      </div>
      <div className="flex flex-wrap gap-3">
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
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="distance_meters">
            Jarak (meter)
          </label>
          <input
            id="distance_meters"
            name="distance_meters"
            type="number"
            min={0}
            className="w-28 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
        <div className="flex flex-col gap-1">
          <label
            className="text-xs font-medium"
            htmlFor="walking_duration_minutes"
          >
            Jalan kaki (menit)
          </label>
          <input
            id="walking_duration_minutes"
            name="walking_duration_minutes"
            type="number"
            min={0}
            className="w-28 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="address">
          Alamat (opsional)
        </label>
        <input
          id="address"
          name="address"
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="description">
          Deskripsi (opsional)
        </label>
        <textarea
          id="description"
          name="description"
          rows={2}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        />
      </div>
      <button
        type="submit"
        disabled={pending}
        className="w-fit rounded-md bg-black px-4 py-1.5 text-sm font-medium text-white disabled:opacity-60 dark:bg-white dark:text-black"
      >
        {pending ? "Menyimpan…" : "Tambah tempat"}
      </button>
      {state?.error && (
        <p className="text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}

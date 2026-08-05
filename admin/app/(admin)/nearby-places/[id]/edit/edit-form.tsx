"use client";

import { useActionState } from "react";
import { updateNearbyPlace, type NearbyPlaceFormState } from "../../actions";

const initialState: NearbyPlaceFormState = undefined;

export function EditNearbyPlaceForm({
  place,
  stations,
}: {
  place: {
    id: string;
    station_id: string;
    name: string;
    category: string;
    latitude: number;
    longitude: number;
    distance_meters: number | null;
    walking_duration_minutes: number | null;
    address: string | null;
    description: string | null;
  };
  stations: { id: string; name: string; code: string }[];
}) {
  const [state, formAction, pending] = useActionState(
    updateNearbyPlace,
    initialState
  );

  return (
    <form
      action={formAction}
      className="flex max-w-md flex-col gap-4 rounded-lg border border-black/10 p-4 dark:border-white/10"
    >
      <input type="hidden" name="id" value={place.id} />
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="station_id">
          Stasiun
        </label>
        <select
          id="station_id"
          name="station_id"
          defaultValue={place.station_id}
          className="rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
        >
          {stations.map((station) => (
            <option key={station.id} value={station.id}>
              {station.name} ({station.code})
            </option>
          ))}
        </select>
      </div>
      <div className="flex flex-col gap-1">
        <label className="text-xs font-medium" htmlFor="name">
          Nama tempat
        </label>
        <input
          id="name"
          name="name"
          required
          defaultValue={place.name}
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
          defaultValue={place.category}
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
            defaultValue={place.latitude}
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
            defaultValue={place.longitude}
            className="w-32 rounded-md border border-black/15 bg-transparent px-2 py-1.5 text-sm dark:border-white/20"
          />
        </div>
      </div>
      <div className="flex gap-3">
        <div className="flex flex-col gap-1">
          <label className="text-xs font-medium" htmlFor="distance_meters">
            Jarak (meter)
          </label>
          <input
            id="distance_meters"
            name="distance_meters"
            type="number"
            min={0}
            defaultValue={place.distance_meters ?? ""}
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
            defaultValue={place.walking_duration_minutes ?? ""}
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
          defaultValue={place.address ?? ""}
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
          defaultValue={place.description ?? ""}
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

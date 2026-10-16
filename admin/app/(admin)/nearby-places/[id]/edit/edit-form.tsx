"use client";

import { useActionState } from "react";
import { Button, ButtonLink } from "@/components/ui/button";
import { SelectField, TextField, TextareaField } from "@/components/ui/fields";
import {
  FormCard,
  FormFooter,
  FormGrid,
  FormMessage,
} from "@/components/ui/form";
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
    <FormCard action={formAction} className="max-w-xl">
      <input type="hidden" name="id" value={place.id} />
      <SelectField
        label="Stasiun"
        name="station_id"
        defaultValue={place.station_id}
      >
        {stations.map((station) => (
          <option key={station.id} value={station.id}>
            {station.name} ({station.code})
          </option>
        ))}
      </SelectField>
      <TextField
        label="Nama tempat"
        name="name"
        required
        maxLength={180}
        defaultValue={place.name}
      />
      <TextField
        label="Kategori"
        name="category"
        required
        maxLength={80}
        defaultValue={place.category}
      />
      <FormGrid>
        <TextField
          label="Latitude"
          name="latitude"
          type="number"
          step="any"
          min={-90}
          max={90}
          required
          defaultValue={place.latitude}
        />
        <TextField
          label="Longitude"
          name="longitude"
          type="number"
          step="any"
          min={-180}
          max={180}
          required
          defaultValue={place.longitude}
        />
        <TextField
          label="Jarak (meter)"
          name="distance_meters"
          type="number"
          min={0}
          optional
          defaultValue={place.distance_meters ?? ""}
        />
        <TextField
          label="Jalan kaki (menit)"
          name="walking_duration_minutes"
          type="number"
          min={0}
          optional
          defaultValue={place.walking_duration_minutes ?? ""}
        />
      </FormGrid>
      <TextField
        label="Alamat"
        name="address"
        optional
        defaultValue={place.address ?? ""}
      />
      <TextareaField
        label="Deskripsi"
        name="description"
        rows={3}
        optional
        defaultValue={place.description ?? ""}
      />
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Simpan perubahan
        </Button>
        <ButtonLink href="/nearby-places" variant="secondary">
          Batal
        </ButtonLink>
        <FormMessage error={state?.error} />
      </FormFooter>
    </FormCard>
  );
}

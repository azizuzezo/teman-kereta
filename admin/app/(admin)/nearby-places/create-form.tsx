"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { SelectField, TextField, TextareaField } from "@/components/ui/fields";
import {
  FormCard,
  FormFooter,
  FormGrid,
  FormMessage,
  useSavedFlag,
} from "@/components/ui/form";
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
  const saved = useSavedFlag(pending, state?.error);

  return (
    <FormCard action={formAction} title="Tambah tempat">
      <FormGrid cols={3}>
        <SelectField label="Stasiun" name="station_id" required defaultValue="">
          <option value="">Pilih stasiun</option>
          {stations.map((station) => (
            <option key={station.id} value={station.id}>
              {station.name} ({station.code})
            </option>
          ))}
        </SelectField>
        <TextField label="Nama tempat" name="name" required maxLength={180} />
        <TextField
          label="Kategori"
          name="category"
          required
          maxLength={80}
          placeholder="mall, kuliner, dst."
        />
      </FormGrid>
      <FormGrid cols={4}>
        <TextField
          label="Latitude"
          name="latitude"
          type="number"
          step="any"
          min={-90}
          max={90}
          required
        />
        <TextField
          label="Longitude"
          name="longitude"
          type="number"
          step="any"
          min={-180}
          max={180}
          required
        />
        <TextField
          label="Jarak (meter)"
          name="distance_meters"
          type="number"
          min={0}
          optional
        />
        <TextField
          label="Jalan kaki (menit)"
          name="walking_duration_minutes"
          type="number"
          min={0}
          optional
        />
      </FormGrid>
      <TextField label="Alamat" name="address" optional />
      <TextareaField label="Deskripsi" name="description" rows={2} optional />
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Tambah tempat
        </Button>
        <FormMessage error={state?.error} saved={saved} savedLabel="Tempat ditambahkan." />
      </FormFooter>
    </FormCard>
  );
}

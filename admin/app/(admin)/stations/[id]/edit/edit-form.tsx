"use client";

import { useActionState } from "react";
import { Button, ButtonLink } from "@/components/ui/button";
import { CheckboxField, TextField, TextareaField } from "@/components/ui/fields";
import {
  FormCard,
  FormFooter,
  FormGrid,
  FormMessage,
} from "@/components/ui/form";
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
    <FormCard action={formAction} className="max-w-xl">
      <input type="hidden" name="id" value={station.id} />
      <TextField
        label="Kode"
        name="code"
        required
        maxLength={40}
        defaultValue={station.code}
      />
      <TextField
        label="Nama stasiun"
        name="name"
        required
        maxLength={160}
        defaultValue={station.name}
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
          defaultValue={station.latitude}
        />
        <TextField
          label="Longitude"
          name="longitude"
          type="number"
          step="any"
          min={-180}
          max={180}
          required
          defaultValue={station.longitude}
        />
      </FormGrid>
      <CheckboxField
        label="Akses kursi roda"
        name="wheelchair_accessible"
        defaultChecked={station.wheelchair_accessible ?? false}
      />
      <TextareaField
        label="Fasilitas (JSON)"
        name="facilities"
        rows={5}
        spellCheck={false}
        hint={'Objek JSON, mis. {"toilet": true}.'}
        className="font-mono text-xs"
        defaultValue={JSON.stringify(station.facilities ?? {}, null, 2)}
      />
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Simpan perubahan
        </Button>
        <ButtonLink href="/stations" variant="secondary">
          Batal
        </ButtonLink>
        <FormMessage error={state?.error} />
      </FormFooter>
    </FormCard>
  );
}

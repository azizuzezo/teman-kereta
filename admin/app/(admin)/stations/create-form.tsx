"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { CheckboxField, TextField } from "@/components/ui/fields";
import {
  FormCard,
  FormFooter,
  FormGrid,
  FormMessage,
  useSavedFlag,
} from "@/components/ui/form";
import { createStation, type StationFormState } from "./actions";

const initialState: StationFormState = undefined;

export function CreateStationForm() {
  const [state, formAction, pending] = useActionState(
    createStation,
    initialState
  );
  const saved = useSavedFlag(pending, state?.error);

  return (
    <FormCard action={formAction} title="Tambah stasiun">
      <FormGrid cols={4}>
        <TextField
          label="Kode"
          name="code"
          required
          maxLength={40}
          placeholder="DEMO-BOO"
        />
        <TextField
          label="Nama stasiun"
          name="name"
          required
          maxLength={160}
          fieldClassName="md:col-span-1"
        />
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
      </FormGrid>
      <CheckboxField label="Akses kursi roda" name="wheelchair_accessible" />
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Tambah stasiun
        </Button>
        <FormMessage error={state?.error} saved={saved} savedLabel="Stasiun ditambahkan." />
      </FormFooter>
    </FormCard>
  );
}

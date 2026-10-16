"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { SelectField, TextField } from "@/components/ui/fields";
import {
  FormCard,
  FormFooter,
  FormGrid,
  FormMessage,
  useSavedFlag,
} from "@/components/ui/form";
import { createLine, type LineFormState } from "./actions";

const initialState: LineFormState = undefined;

export function CreateLineForm({
  operators,
  transportModes,
}: {
  operators: { id: string; name: string }[];
  transportModes: readonly string[];
}) {
  const [state, formAction, pending] = useActionState(createLine, initialState);
  const saved = useSavedFlag(pending, state?.error);

  return (
    <FormCard action={formAction} title="Tambah lini">
      <FormGrid cols={3}>
        <SelectField label="Operator" name="operator_id" required defaultValue="">
          <option value="">Pilih operator</option>
          {operators.map((operator) => (
            <option key={operator.id} value={operator.id}>
              {operator.name}
            </option>
          ))}
        </SelectField>
        <TextField
          label="Kode"
          name="code"
          required
          maxLength={40}
          placeholder="DEMO-KRL"
        />
        <TextField label="Nama lini" name="name" required maxLength={160} />
        <SelectField
          label="Moda"
          name="transport_mode"
          defaultValue={transportModes[0]}
        >
          {transportModes.map((mode) => (
            <option key={mode} value={mode}>
              {mode}
            </option>
          ))}
        </SelectField>
        <TextField
          label="Warna"
          name="color"
          optional
          placeholder="#147D64"
          hint="Format #RRGGBB."
        />
        <TextField
          label="Warna teks"
          name="text_color"
          optional
          placeholder="#FFFFFF"
          hint="Format #RRGGBB."
        />
      </FormGrid>
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Tambah lini
        </Button>
        <FormMessage error={state?.error} saved={saved} savedLabel="Lini ditambahkan." />
      </FormFooter>
    </FormCard>
  );
}

"use client";

import { useActionState } from "react";
import { Button, ButtonLink } from "@/components/ui/button";
import { SelectField, TextField } from "@/components/ui/fields";
import {
  FormCard,
  FormFooter,
  FormGrid,
  FormMessage,
} from "@/components/ui/form";
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
    <FormCard action={formAction} className="max-w-xl">
      <input type="hidden" name="id" value={line.id} />
      <SelectField
        label="Operator"
        name="operator_id"
        defaultValue={line.operator_id}
      >
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
        defaultValue={line.code}
      />
      <TextField
        label="Nama lini"
        name="name"
        required
        maxLength={160}
        defaultValue={line.name}
      />
      <SelectField
        label="Moda"
        name="transport_mode"
        defaultValue={line.transport_mode}
      >
        {transportModes.map((mode) => (
          <option key={mode} value={mode}>
            {mode}
          </option>
        ))}
      </SelectField>
      <FormGrid>
        <TextField
          label="Warna"
          name="color"
          optional
          defaultValue={line.color ?? ""}
          placeholder="#147D64"
          hint="Format #RRGGBB."
        />
        <TextField
          label="Warna teks"
          name="text_color"
          optional
          defaultValue={line.text_color ?? ""}
          placeholder="#FFFFFF"
          hint="Format #RRGGBB."
        />
      </FormGrid>
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Simpan perubahan
        </Button>
        <ButtonLink href="/lines" variant="secondary">
          Batal
        </ButtonLink>
        <FormMessage error={state?.error} />
      </FormFooter>
    </FormCard>
  );
}

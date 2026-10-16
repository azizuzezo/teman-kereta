"use client";

import { useActionState } from "react";
import { Button, ButtonLink } from "@/components/ui/button";
import { SelectField, TextField } from "@/components/ui/fields";
import {
  FormCard,
  FormFooter,
  FormMessage,
} from "@/components/ui/form";
import { updateOperator, type OperatorFormState } from "../../actions";

const initialState: OperatorFormState = undefined;

export function EditOperatorForm({
  operator,
  operatorTypes,
  dataSourceTypes,
}: {
  operator: {
    id: string;
    name: string;
    operator_type: string;
    data_source_type: string;
    website: string | null;
  };
  operatorTypes: readonly string[];
  dataSourceTypes: readonly string[];
}) {
  const [state, formAction, pending] = useActionState(
    updateOperator,
    initialState
  );

  return (
    <FormCard action={formAction} className="max-w-xl">
      <input type="hidden" name="id" value={operator.id} />
      <TextField
        label="Nama operator"
        name="name"
        required
        maxLength={160}
        defaultValue={operator.name}
      />
      <SelectField
        label="Jenis"
        name="operator_type"
        defaultValue={operator.operator_type}
      >
        {operatorTypes.map((type) => (
          <option key={type} value={type}>
            {type}
          </option>
        ))}
      </SelectField>
      <SelectField
        label="Sumber data"
        name="data_source_type"
        defaultValue={operator.data_source_type}
      >
        {dataSourceTypes.map((type) => (
          <option key={type} value={type}>
            {type}
          </option>
        ))}
      </SelectField>
      <TextField
        label="Website"
        name="website"
        type="url"
        optional
        defaultValue={operator.website ?? ""}
      />
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Simpan perubahan
        </Button>
        <ButtonLink href="/operators" variant="secondary">
          Batal
        </ButtonLink>
        <FormMessage error={state?.error} />
      </FormFooter>
    </FormCard>
  );
}

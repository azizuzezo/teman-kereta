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
import { createOperator, type OperatorFormState } from "./actions";

const initialState: OperatorFormState = undefined;

export function CreateOperatorForm({
  operatorTypes,
  dataSourceTypes,
}: {
  operatorTypes: readonly string[];
  dataSourceTypes: readonly string[];
}) {
  const [state, formAction, pending] = useActionState(
    createOperator,
    initialState
  );
  const saved = useSavedFlag(pending, state?.error);

  return (
    <FormCard action={formAction} title="Tambah operator">
      <FormGrid cols={4}>
        <TextField label="Nama operator" name="name" required maxLength={160} />
        <SelectField
          label="Jenis"
          name="operator_type"
          defaultValue={operatorTypes[0]}
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
          defaultValue={dataSourceTypes[0]}
        >
          {dataSourceTypes.map((type) => (
            <option key={type} value={type}>
              {type}
            </option>
          ))}
        </SelectField>
        <TextField label="Website" name="website" type="url" optional />
      </FormGrid>
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Tambah operator
        </Button>
        <FormMessage error={state?.error} saved={saved} savedLabel="Operator ditambahkan." />
      </FormFooter>
    </FormCard>
  );
}

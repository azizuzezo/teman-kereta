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
import { createServiceAlert, type ServiceAlertFormState } from "./actions";

const initialState: ServiceAlertFormState = undefined;
const SEVERITIES = ["info", "warning", "severe", "critical"];

export function CreateServiceAlertForm({
  operators,
}: {
  operators: { id: string; name: string }[];
}) {
  const [state, formAction, pending] = useActionState(
    createServiceAlert,
    initialState
  );
  const saved = useSavedFlag(pending, state?.error);

  return (
    <FormCard action={formAction} title="Terbitkan peringatan">
      <FormGrid cols={3}>
        <SelectField label="Operator" name="operator_id" required defaultValue="">
          <option value="">Pilih operator</option>
          {operators.map((operator) => (
            <option key={operator.id} value={operator.id}>
              {operator.name}
            </option>
          ))}
        </SelectField>
        <SelectField
          label="Tingkat keparahan"
          name="severity"
          defaultValue="info"
        >
          {SEVERITIES.map((severity) => (
            <option key={severity} value={severity}>
              {severity}
            </option>
          ))}
        </SelectField>
        <TextField label="Judul" name="title" required maxLength={180} />
      </FormGrid>
      <TextareaField label="Deskripsi" name="description" required rows={3} />
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Terbitkan peringatan
        </Button>
        <FormMessage error={state?.error} saved={saved} savedLabel="Peringatan diterbitkan." />
      </FormFooter>
    </FormCard>
  );
}

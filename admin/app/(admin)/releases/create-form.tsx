"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { FileField, TextField, TextareaField } from "@/components/ui/fields";
import {
  FormCard,
  FormFooter,
  FormGrid,
  FormMessage,
  useSavedFlag,
} from "@/components/ui/form";
import { createRelease, type ReleaseFormState } from "./actions";

const initialState: ReleaseFormState = undefined;

export function CreateReleaseForm() {
  const [state, formAction, pending] = useActionState(
    createRelease,
    initialState
  );
  const saved = useSavedFlag(pending, state?.error);

  return (
    <FormCard action={formAction} title="Terbitkan rilis">
      <FormGrid cols={3}>
        <TextField
          label="Version code"
          name="version_code"
          type="number"
          min={1}
          step={1}
          required
        />
        <TextField
          label="Version name"
          name="version_name"
          placeholder="1.2.0"
          required
        />
        <TextField
          label="Versi minimum yang didukung"
          name="min_supported_version_code"
          type="number"
          min={1}
          step={1}
          optional
        />
      </FormGrid>
      <FileField
        label="Berkas APK"
        name="apk"
        accept=".apk,application/vnd.android.package-archive"
        required
        hint="Maksimal 200 MB. Unggahan besar bisa memakan waktu beberapa menit."
      />
      <TextareaField
        label="Changelog"
        name="changelog"
        rows={3}
        optional
        placeholder="Apa yang berubah pada rilis ini?"
      />
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Mengunggah…">
          Terbitkan rilis
        </Button>
        <FormMessage error={state?.error} saved={saved} savedLabel="Rilis diterbitkan." />
      </FormFooter>
    </FormCard>
  );
}

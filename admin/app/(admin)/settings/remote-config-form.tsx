"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { TextareaField } from "@/components/ui/fields";
import {
  FormCard,
  FormFooter,
  FormMessage,
  useSavedFlag,
} from "@/components/ui/form";
import { updateRemoteConfig, type SettingsFormState } from "./actions";

const initialState: SettingsFormState = undefined;

export function RemoteConfigForm({ value }: { value: unknown }) {
  const [state, formAction, pending] = useActionState(
    updateRemoteConfig,
    initialState
  );
  const saved = useSavedFlag(pending, state?.error);

  return (
    <FormCard action={formAction} title="Remote configuration">
      <TextareaField
        label="Konfigurasi (JSON)"
        name="remote_config"
        rows={10}
        spellCheck={false}
        hint="Harus berupa objek JSON."
        className="font-mono text-xs"
        defaultValue={JSON.stringify(value, null, 2)}
      />
      <FormFooter>
        <Button type="submit" loading={pending} loadingLabel="Menyimpan…">
          Simpan remote config
        </Button>
        <FormMessage error={state?.error} saved={saved} savedLabel="Konfigurasi tersimpan." />
      </FormFooter>
    </FormCard>
  );
}

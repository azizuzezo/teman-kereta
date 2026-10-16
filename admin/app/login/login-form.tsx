"use client";

import { useActionState, useState } from "react";
import { Button } from "@/components/ui/button";
import { FormMessage } from "@/components/ui/form";
import { Field, TextField } from "@/components/ui/fields";
import { EyeIcon, EyeOffIcon } from "@/components/ui/icons";
import { login, type LoginState } from "./actions";

const initialState: LoginState = undefined;

export function LoginForm() {
  const [state, formAction, pending] = useActionState(login, initialState);
  const [showPassword, setShowPassword] = useState(false);

  return (
    <form action={formAction} className="flex flex-col gap-5">
      <TextField
        label="Email"
        name="email"
        type="email"
        required
        autoComplete="username"
        inputMode="email"
        autoCapitalize="none"
        spellCheck={false}
      />
      <Field label="Password" htmlFor="password">
        <div className="relative">
          <input
            id="password"
            name="password"
            type={showPassword ? "text" : "password"}
            required
            autoComplete="current-password"
            className="min-h-11 w-full rounded-control border border-line-strong bg-surface pl-3 pr-12 text-sm text-ink"
          />
          <button
            type="button"
            onClick={() => setShowPassword((value) => !value)}
            aria-label={
              showPassword ? "Sembunyikan password" : "Tampilkan password"
            }
            aria-pressed={showPassword}
            className="absolute inset-y-0 right-0 inline-flex w-11 items-center justify-center rounded-r-control text-ink-muted hover:text-ink"
          >
            {showPassword ? <EyeOffIcon /> : <EyeIcon />}
          </button>
        </div>
      </Field>
      <FormMessage error={state?.error} />
      <Button
        type="submit"
        loading={pending}
        loadingLabel="Memproses…"
        className="w-full"
      >
        Masuk
      </Button>
    </form>
  );
}

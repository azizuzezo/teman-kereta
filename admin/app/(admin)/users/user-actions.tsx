"use client";

import { useActionState, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { ConfirmButton } from "@/components/ui/confirm-button";
import { TextField } from "@/components/ui/fields";
import { FormMessage, useSavedFlag } from "@/components/ui/form";
import { deleteUser, sendPasswordReset } from "./actions";

export function ResetPasswordButton({
  userId,
  email,
}: {
  userId: string;
  email: string | null;
}) {
  const [state, formAction, pending] = useActionState(
    sendPasswordReset,
    undefined
  );
  const saved = useSavedFlag(pending, state?.error);

  if (!email) {
    return <span className="text-xs text-ink-muted">Tanpa email</span>;
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <ConfirmButton
        action={formAction}
        fields={{ id: userId }}
        label="Reset sandi"
        ariaLabel={`Kirim email reset kata sandi ke ${email}`}
        title="Kirim email reset kata sandi?"
        description={`Tautan reset dikirim ke ${email}. Kata sandi lama tetap berlaku sampai pengguna menggantinya sendiri.`}
        confirmLabel="Ya, kirim"
        variant="primary"
        triggerVariant="ghost"
        loading={pending}
        loadingLabel="Mengirim…"
      />
      <FormMessage
        error={state?.error}
        saved={saved}
        savedLabel="Email reset terkirim."
        className="max-w-64 text-right text-xs"
      />
    </div>
  );
}

/**
 * Like ConfirmButton, but the admin must type the user's email (or "HAPUS"
 * when the account has none) before the destructive button enables.
 */
export function DeleteUserButton({
  userId,
  email,
}: {
  userId: string;
  email: string | null;
}) {
  const [state, formAction, pending] = useActionState(deleteUser, undefined);
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [typed, setTyped] = useState("");

  const expected = email ?? "HAPUS";
  const label = email ?? "akun tanpa email";
  const matches = typed.trim().toLowerCase() === expected.toLowerCase();

  function close() {
    dialogRef.current?.close();
    setTyped("");
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <Button
        variant="ghost"
        size="sm"
        aria-label={`Hapus akun ${label}`}
        loading={pending}
        loadingLabel="Menghapus…"
        className="text-bad hover:bg-bad-soft"
        onClick={() => dialogRef.current?.showModal()}
      >
        Hapus akun
      </Button>
      <dialog
        ref={dialogRef}
        aria-label={`Hapus akun ${label}`}
        className="m-auto w-[min(92vw,26rem)] rounded-card border border-line bg-surface p-0 text-ink shadow-xl"
        onClick={(event) => {
          if (event.target === dialogRef.current) close();
        }}
        onClose={() => setTyped("")}
      >
        <form
          action={formAction}
          onSubmit={close}
          className="flex flex-col gap-4 p-6"
        >
          <input type="hidden" name="id" value={userId} />
          <h2 className="text-lg font-bold">Hapus akun ini selamanya?</h2>
          <p className="text-sm text-ink-muted">
            Profil, favorit, postingan forum, komentar, dan semua data
            pengguna ikut terhapus, termasuk foto yang diunggah. Ini tidak bisa
            dibatalkan.
          </p>
          <TextField
            label={
              email
                ? `Ketik ${email} untuk melanjutkan`
                : "Ketik HAPUS untuk melanjutkan"
            }
            name="confirm"
            id={`confirm-${userId}`}
            value={typed}
            onChange={(event) => setTyped(event.target.value)}
            autoComplete="off"
            autoCapitalize="off"
            spellCheck={false}
          />
          <div className="flex flex-wrap justify-end gap-2">
            <Button variant="secondary" onClick={close} autoFocus>
              Batal
            </Button>
            <Button type="submit" variant="danger" disabled={!matches}>
              Ya, hapus akun
            </Button>
          </div>
        </form>
      </dialog>
      <FormMessage
        error={state?.error}
        className="max-w-64 text-right text-xs"
      />
    </div>
  );
}

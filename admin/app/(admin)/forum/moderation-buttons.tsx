import { SubmitButton } from "@/components/ui/button";
import { ConfirmButton } from "@/components/ui/confirm-button";
import type { ModerationStatus } from "./actions";

const MODERATION_STATUSES: ModerationStatus[] = ["visible", "hidden", "removed"];

export const STATUS_LABELS: Record<string, string> = {
  all: "Semua",
  visible: "Tampil",
  hidden: "Disembunyikan",
  removed: "Dihapus",
};

const ACTION_LABELS: Record<ModerationStatus, string> = {
  visible: "Tampilkan",
  hidden: "Sembunyikan",
  removed: "Hapus",
};

/**
 * Moderation buttons for a forum post or comment: one per status other than
 * the current one. Hiding and showing apply directly; removing asks first.
 * `bindAction` returns the existing server action bound to this record, so
 * every action and audit entry stays exactly as before.
 */
export function ModerationButtons({
  current,
  noun,
  bindAction,
}: {
  current: string;
  noun: "postingan" | "komentar";
  bindAction: (status: ModerationStatus) => (formData: FormData) => void | Promise<void>;
}) {
  return (
    <>
      {MODERATION_STATUSES.filter((status) => status !== current).map(
        (status) =>
          status === "removed" ? (
            <ConfirmButton
              key={status}
              action={bindAction(status)}
              label={ACTION_LABELS[status]}
              ariaLabel={`Hapus ${noun} ini`}
              title={`Hapus ${noun} ini?`}
              description={`Konten tidak tampil lagi di aplikasi. Kamu masih bisa memulihkannya dengan tombol Tampilkan dari filter Dihapus.`}
              confirmLabel="Ya, hapus"
              triggerVariant="secondary"
            />
          ) : (
            <form key={status} action={bindAction(status)}>
              <SubmitButton
                variant="secondary"
                size="sm"
                aria-label={`${ACTION_LABELS[status]} ${noun} ini`}
                loadingLabel="Menyimpan…"
              >
                {ACTION_LABELS[status]}
              </SubmitButton>
            </form>
          )
      )}
    </>
  );
}

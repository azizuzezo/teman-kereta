"use client";

import { DeleteRowButton } from "@/components/ui/delete-row-button";
import { deleteLine } from "./actions";

export function DeleteLineButton({
  lineId,
  name,
}: {
  lineId: string;
  name: string;
}) {
  return (
    <DeleteRowButton
      action={deleteLine}
      id={lineId}
      entityLabel={`lini "${name}"`}
      consequence="Lini yang masih punya jadwal trip tidak bisa dihapus. Penghapusan tidak bisa dibatalkan."
    />
  );
}

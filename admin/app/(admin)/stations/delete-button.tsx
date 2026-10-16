"use client";

import { DeleteRowButton } from "@/components/ui/delete-row-button";
import { deleteStation } from "./actions";

export function DeleteStationButton({
  stationId,
  name,
}: {
  stationId: string;
  name: string;
}) {
  return (
    <DeleteRowButton
      action={deleteStation}
      id={stationId}
      entityLabel={`stasiun "${name}"`}
      consequence="Stasiun yang masih dipakai jadwal tidak bisa dihapus. Penghapusan tidak bisa dibatalkan."
    />
  );
}

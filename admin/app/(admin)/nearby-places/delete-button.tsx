"use client";

import { DeleteRowButton } from "@/components/ui/delete-row-button";
import { deleteNearbyPlace } from "./actions";

export function DeleteNearbyPlaceButton({
  placeId,
  name,
}: {
  placeId: string;
  name: string;
}) {
  return (
    <DeleteRowButton
      action={deleteNearbyPlace}
      id={placeId}
      entityLabel={`tempat "${name}"`}
      consequence="Data tempat ini akan hilang dari aplikasi. Penghapusan tidak bisa dibatalkan."
    />
  );
}

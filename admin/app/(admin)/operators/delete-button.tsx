"use client";

import { DeleteRowButton } from "@/components/ui/delete-row-button";
import { deleteOperator } from "./actions";

export function DeleteOperatorButton({
  operatorId,
  name,
}: {
  operatorId: string;
  name: string;
}) {
  return (
    <DeleteRowButton
      action={deleteOperator}
      id={operatorId}
      entityLabel={`operator "${name}"`}
      consequence="Operator yang masih punya lini tidak bisa dihapus. Penghapusan tidak bisa dibatalkan."
    />
  );
}

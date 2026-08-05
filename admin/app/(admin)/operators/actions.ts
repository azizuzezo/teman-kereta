"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";
import { OPERATOR_TYPES, DATA_SOURCE_TYPES } from "./constants";

export type OperatorFormState = { error?: string } | undefined;

function validateOperatorFields(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  const operatorType = String(formData.get("operator_type") ?? "");
  const dataSourceType = String(formData.get("data_source_type") ?? "");
  const website = String(formData.get("website") ?? "").trim() || null;

  if (!name || name.length > 160) {
    return { error: "Nama operator wajib diisi (maks. 160 karakter)." } as const;
  }
  if (!OPERATOR_TYPES.includes(operatorType as (typeof OPERATOR_TYPES)[number])) {
    return { error: "Jenis operator tidak valid." } as const;
  }
  if (
    !DATA_SOURCE_TYPES.includes(
      dataSourceType as (typeof DATA_SOURCE_TYPES)[number]
    )
  ) {
    return { error: "Jenis sumber data tidak valid." } as const;
  }

  return {
    fields: {
      name,
      operator_type: operatorType,
      data_source_type: dataSourceType,
      website,
    },
  } as const;
}

export async function createOperator(
  _prevState: OperatorFormState,
  formData: FormData
): Promise<OperatorFormState> {
  const session = await verifyAdminSession();

  const validated = validateOperatorFields(formData);
  if ("error" in validated) {
    return validated;
  }

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("operators")
    .insert(validated.fields)
    .select("id")
    .single();

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "create",
    tableName: "operators",
    recordId: data.id,
    changes: validated.fields,
  });

  revalidatePath("/operators");
}

export async function updateOperator(
  _prevState: OperatorFormState,
  formData: FormData
): Promise<OperatorFormState> {
  const session = await verifyAdminSession();
  const id = String(formData.get("id") ?? "");
  if (!id) {
    return { error: "ID operator tidak ditemukan." };
  }

  const validated = validateOperatorFields(formData);
  if ("error" in validated) {
    return validated;
  }

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("operators")
    .update(validated.fields)
    .eq("id", id);

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "update",
    tableName: "operators",
    recordId: id,
    changes: validated.fields,
  });

  revalidatePath("/operators");
  redirect("/operators");
}

export async function toggleOperatorActive(formData: FormData) {
  const session = await verifyAdminSession();
  const id = String(formData.get("id"));
  const nextActive = formData.get("is_active") === "true";

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("operators")
    .update({ is_active: nextActive })
    .eq("id", id);

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "update",
      tableName: "operators",
      recordId: id,
      changes: { is_active: nextActive },
    });
  }

  revalidatePath("/operators");
}

export async function deleteOperator(formData: FormData) {
  const session = await verifyAdminSession();
  const id = String(formData.get("id"));

  const supabase = createServiceClient();
  const { error } = await supabase.from("operators").delete().eq("id", id);

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "delete",
      tableName: "operators",
      recordId: id,
    });
  }

  revalidatePath("/operators");
}

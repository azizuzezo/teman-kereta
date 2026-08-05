"use server";

import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

export type SettingsFormState = { error?: string } | undefined;

export async function updateMaintenanceMode(formData: FormData) {
  const session = await verifyAdminSession();
  const enabled = formData.get("maintenance_mode") === "on";

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("app_config")
    .update({ value: enabled })
    .eq("key", "maintenance_mode");

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "update",
      tableName: "app_config",
      recordId: "maintenance_mode",
      changes: { value: enabled },
    });
  }

  revalidatePath("/settings");
}

export async function updateRemoteConfig(
  _prevState: SettingsFormState,
  formData: FormData
): Promise<SettingsFormState> {
  const session = await verifyAdminSession();
  const raw = String(formData.get("remote_config") ?? "{}");

  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    return { error: "JSON tidak valid." };
  }
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return { error: "Remote config harus berupa objek JSON." };
  }

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("app_config")
    .update({ value })
    .eq("key", "remote_config");

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "update",
    tableName: "app_config",
    recordId: "remote_config",
    changes: { value },
  });

  revalidatePath("/settings");
}

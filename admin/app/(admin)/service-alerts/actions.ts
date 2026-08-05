"use server";

import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

export type ServiceAlertFormState = { error?: string } | undefined;

const SEVERITIES = ["info", "warning", "severe", "critical"] as const;

export async function createServiceAlert(
  _prevState: ServiceAlertFormState,
  formData: FormData
): Promise<ServiceAlertFormState> {
  const session = await verifyAdminSession();

  const operatorId = String(formData.get("operator_id") ?? "");
  const title = String(formData.get("title") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const severity = String(formData.get("severity") ?? "");

  if (!operatorId) return { error: "Pilih operator." };
  if (!title || title.length > 180) return { error: "Judul wajib diisi (maks. 180 karakter)." };
  if (!description) return { error: "Deskripsi wajib diisi." };
  if (!SEVERITIES.includes(severity as (typeof SEVERITIES)[number])) {
    return { error: "Tingkat keparahan tidak valid." };
  }

  const supabase = createServiceClient();
  const { data, error } = await supabase
    .from("service_alerts")
    .insert({
      operator_id: operatorId,
      title,
      description,
      severity,
      starts_at: new Date().toISOString(),
      source: "admin_panel",
      is_official: true,
    })
    .select("id")
    .single();

  if (error) {
    return { error: `Gagal menyimpan: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "create",
    tableName: "service_alerts",
    recordId: data.id,
    changes: { title, severity },
  });

  revalidatePath("/service-alerts");
}

export async function resolveServiceAlert(formData: FormData) {
  const session = await verifyAdminSession();
  const id = String(formData.get("id"));

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("service_alerts")
    .update({ ends_at: new Date().toISOString() })
    .eq("id", id);

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "update",
      tableName: "service_alerts",
      recordId: id,
      changes: { resolved: true },
    });
  }

  revalidatePath("/service-alerts");
}

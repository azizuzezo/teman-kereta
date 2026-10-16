"use server";

import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

const STATUSES = ["open", "in_progress", "resolved", "dismissed"] as const;

export async function updateAppReportStatus(formData: FormData) {
  const session = await verifyAdminSession();
  const id = String(formData.get("id"));
  const status = String(formData.get("status"));

  if (!STATUSES.includes(status as (typeof STATUSES)[number])) {
    return;
  }

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("app_reports")
    .update({ status })
    .eq("id", id);

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "update",
      tableName: "app_reports",
      recordId: id,
      changes: { status },
    });
  }

  revalidatePath("/app-reports");
  revalidatePath(`/app-reports/${id}`);
}

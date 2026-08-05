"use server";

import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

const STATUSES = ["pending", "verified", "rejected", "resolved", "expired"] as const;

export async function moderateUserReport(formData: FormData) {
  const session = await verifyAdminSession();
  const id = String(formData.get("id"));
  const status = String(formData.get("status"));

  if (!STATUSES.includes(status as (typeof STATUSES)[number])) {
    return;
  }

  const supabase = createServiceClient();
  const { error } = await supabase
    .from("user_reports")
    .update({ status })
    .eq("id", id);

  if (!error) {
    await recordAudit({
      adminUserId: session.userId,
      action: "update",
      tableName: "user_reports",
      recordId: id,
      changes: { status },
    });
  }

  revalidatePath("/user-reports");
}

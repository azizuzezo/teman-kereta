import "server-only";

import { createServiceClient } from "./supabase/service";

type AuditAction = "create" | "update" | "delete";

/**
 * Records one row in `audit_log` (PRD §36 "Audit log"). Called by every
 * mutating server action right after its write succeeds — deliberately not
 * a DB trigger, so the log can capture *which admin* made the change and a
 * readable `changes` payload, not just the raw row diff.
 */
export async function recordAudit(params: {
  adminUserId: string;
  action: AuditAction;
  tableName: string;
  recordId: string | null;
  changes?: Record<string, unknown>;
}) {
  const service = createServiceClient();
  await service.from("audit_log").insert({
    admin_user_id: params.adminUserId,
    action: params.action,
    table_name: params.tableName,
    record_id: params.recordId,
    changes: params.changes ?? null,
  });
}

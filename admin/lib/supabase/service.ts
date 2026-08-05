import "server-only";

import { createClient as createSupabaseClient } from "@supabase/supabase-js";

/**
 * Bypasses RLS entirely via the service-role key. This is the ONLY client
 * used for reference-data reads/writes (operators/lines/stations/service
 * alerts/user reports/admin_users/audit_log/app_config) — matching this
 * project's existing "reference data writes go through a trusted server
 * connection, not a client" posture (see ../../docs/backend-local.md at the
 * repo root). Every caller MUST verify the signed-in user is an admin
 * first (see lib/dal.ts) — this client itself does not check that.
 */
export function createServiceClient() {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}

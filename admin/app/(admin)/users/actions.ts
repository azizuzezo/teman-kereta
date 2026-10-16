"use server";

import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

export type UserActionState = { error?: string } | undefined;

// Same deep link the app's own "Lupa kata sandi" flow uses, so a link sent
// from here lands on the app's reset-password page.
const RESET_REDIRECT = "temankereta://app/account/reset-password";

// Buckets whose objects live under `<user id>/...` (see the app's
// deleteAccount). Supabase will not delete files for us when the user goes.
const USER_FILE_BUCKETS = ["avatars", "forum-post-images"] as const;

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Emails the user a password reset link (same mail the app's own reset flow
 * sends). The admin never sees or sets a password. Supabase rate-limits
 * recovery mails per address, so a "too many requests" error is surfaced as-is.
 */
export async function sendPasswordReset(
  _prevState: UserActionState,
  formData: FormData
): Promise<UserActionState> {
  const session = await verifyAdminSession();
  const id = String(formData.get("id") ?? "");
  if (!UUID.test(id)) return { error: "ID pengguna tidak valid." };

  const supabase = createServiceClient();
  // Look the address up server-side rather than trusting what the form sent.
  const { data, error: lookupError } = await supabase.auth.admin.getUserById(id);
  const email = data?.user?.email;
  if (lookupError || !email) {
    return { error: "Pengguna ini tidak punya email, jadi tidak bisa dikirimi tautan reset." };
  }

  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: RESET_REDIRECT,
  });
  if (error) {
    return { error: `Gagal mengirim email reset: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "update",
    tableName: "users",
    recordId: id,
    changes: { password_reset_email_sent: true },
  });

  revalidatePath("/users");
}

/** Removes every object under `<bucket>/<prefix>/`, including per-post subfolders. */
async function removeUserFiles(
  supabase: ReturnType<typeof createServiceClient>,
  bucket: string,
  prefix: string
): Promise<void> {
  const storage = supabase.storage.from(bucket);
  const pageSize = 100;
  const entries: { id: string | null; name: string }[] = [];
  for (let offset = 0; ; offset += pageSize) {
    const { data, error } = await storage.list(prefix, {
      limit: pageSize,
      offset,
    });
    if (error) throw error;
    entries.push(...data);
    if (data.length < pageSize) break;
  }

  const files: string[] = [];
  for (const entry of entries) {
    // Folders come back without an id; files have one.
    if (entry.id === null) {
      await removeUserFiles(supabase, bucket, `${prefix}/${entry.name}`);
    } else {
      files.push(`${prefix}/${entry.name}`);
    }
  }
  if (files.length > 0) {
    const { error } = await storage.remove(files);
    if (error) throw error;
  }
}

/**
 * Permanently deletes a user and, through ON DELETE CASCADE, everything
 * attached to the account — the admin-side twin of the app's
 * `delete_my_account`. Cannot be undone. Refuses to delete the signed-in
 * admin or any other admin; remove admin access first for that.
 */
export async function deleteUser(
  _prevState: UserActionState,
  formData: FormData
): Promise<UserActionState> {
  const session = await verifyAdminSession();
  const id = String(formData.get("id") ?? "");
  if (!UUID.test(id)) return { error: "ID pengguna tidak valid." };

  if (id === session.userId) {
    return { error: "Kamu tidak bisa menghapus akunmu sendiri dari panel admin." };
  }

  const supabase = createServiceClient();

  const { data: adminRow } = await supabase
    .from("admin_users")
    .select("user_id")
    .eq("user_id", id)
    .maybeSingle();
  if (adminRow) {
    return {
      error:
        "Akun ini adalah admin. Cabut akses admin-nya dulu sebelum menghapus akun.",
    };
  }

  // Files first, best-effort: a storage hiccup shouldn't make an account
  // undeletable. Report it afterwards so orphaned files are not silent.
  const failedBuckets: string[] = [];
  for (const bucket of USER_FILE_BUCKETS) {
    try {
      await removeUserFiles(supabase, bucket, id);
    } catch {
      failedBuckets.push(bucket);
    }
  }

  const { error } = await supabase.auth.admin.deleteUser(id);
  if (error) {
    return { error: `Gagal menghapus akun: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "delete",
    tableName: "users",
    recordId: id,
    // No email or name on purpose: the account is deleted for privacy, so the
    // log keeps only the id and what happened to the files.
    changes:
      failedBuckets.length > 0
        ? { via: "admin", storage_cleanup_failed: failedBuckets }
        : { via: "admin" },
  });

  revalidatePath("/users");
}

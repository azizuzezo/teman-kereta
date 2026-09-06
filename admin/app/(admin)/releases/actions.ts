"use server";

import { revalidatePath } from "next/cache";
import { verifyAdminSession } from "@/lib/dal";
import { createServiceClient } from "@/lib/supabase/service";
import { recordAudit } from "@/lib/audit";

export type ReleaseFormState = { error?: string } | undefined;

/**
 * Publishes a new APK release. Uploads go straight through this server
 * action (not a client-side direct-to-storage upload) because the
 * `releases` Storage bucket only has a public-read policy today (see
 * supabase/migrations/20260822103000_app_releases.sql) — there is no
 * authenticated-insert policy on storage.objects for it, so a browser
 * client with the anon/authenticated key cannot upload. Raising
 * `experimental.serverActions.bodySizeLimit` in next.config.ts (to handle
 * multi-MB APKs) and uploading via the service-role client here avoids
 * needing a new storage RLS policy.
 */
export async function createRelease(
  _prevState: ReleaseFormState,
  formData: FormData
): Promise<ReleaseFormState> {
  const session = await verifyAdminSession();

  const versionCodeRaw = String(formData.get("version_code") ?? "").trim();
  const versionName = String(formData.get("version_name") ?? "").trim();
  const changelog = String(formData.get("changelog") ?? "").trim();
  const minSupportedRaw = String(
    formData.get("min_supported_version_code") ?? ""
  ).trim();
  const file = formData.get("apk");

  const versionCode = Number(versionCodeRaw);
  if (!Number.isInteger(versionCode) || versionCode <= 0) {
    return { error: "Version code harus berupa bilangan bulat positif." };
  }
  if (!versionName) {
    return { error: "Version name wajib diisi." };
  }
  if (!(file instanceof File) || file.size === 0) {
    return { error: "Berkas APK wajib diunggah." };
  }
  if (!file.name.toLowerCase().endsWith(".apk")) {
    return { error: "Berkas harus berformat .apk." };
  }

  let minSupportedVersionCode: number | null = null;
  if (minSupportedRaw) {
    const parsed = Number(minSupportedRaw);
    if (!Number.isInteger(parsed) || parsed <= 0) {
      return { error: "Minimum versi didukung harus berupa bilangan bulat positif." };
    }
    minSupportedVersionCode = parsed;
  }

  const supabase = createServiceClient();

  const { data: existing } = await supabase
    .from("app_releases")
    .select("id")
    .eq("version_code", versionCode)
    .maybeSingle();

  if (existing) {
    return { error: `Version code ${versionCode} sudah digunakan.` };
  }

  const objectPath = `${versionCode}.apk`;
  const { error: uploadError } = await supabase.storage
    .from("releases")
    .upload(objectPath, file, {
      contentType: "application/vnd.android.package-archive",
      upsert: false,
    });

  if (uploadError) {
    return { error: `Gagal mengunggah APK: ${uploadError.message}` };
  }

  const {
    data: { publicUrl },
  } = supabase.storage.from("releases").getPublicUrl(objectPath);

  const { data, error } = await supabase
    .from("app_releases")
    .insert({
      version_code: versionCode,
      version_name: versionName,
      apk_url: publicUrl,
      changelog: changelog || null,
      min_supported_version_code: minSupportedVersionCode,
    })
    .select("id")
    .single();

  if (error) {
    if (error.code === "23505") {
      return { error: `Version code ${versionCode} sudah digunakan.` };
    }
    return { error: `Gagal menyimpan rilis: ${error.message}` };
  }

  await recordAudit({
    adminUserId: session.userId,
    action: "create",
    tableName: "app_releases",
    recordId: data.id,
    changes: { version_code: versionCode, version_name: versionName },
  });

  // Broadcast a push notification to every registered device so users who
  // don't happen to open the app right away still hear about the update
  // (the in-app update dialog only fires on next launch/foreground).
  const { data: tokenRows } = await supabase
    .from("device_tokens")
    .select("user_id");
  const userIds = Array.from(
    new Set((tokenRows ?? []).map((row) => row.user_id))
  );
  if (userIds.length > 0) {
    const { error: pushError } = await supabase.functions.invoke(
      "send-push-notification",
      {
        body: {
          user_ids: userIds,
          title: "Pembaruan Teman Kereta tersedia",
          body: `Versi ${versionName} sudah bisa diunduh${
            changelog ? `: ${changelog}` : "."
          }`,
        },
      }
    );
    // Best-effort: a failed broadcast should never block the release from
    // being published -- the in-app update dialog is the fallback path.
    if (pushError) {
      console.error("Gagal mengirim push notification rilis:", pushError);
    }
  }

  revalidatePath("/releases");
}

import "server-only";

import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "./supabase/server";
import { createServiceClient } from "./supabase/service";

export type AdminSession = {
  userId: string;
  email: string | null;
  displayName: string | null;
};

/**
 * The one real authorization check for the whole admin panel. Signing in
 * with Supabase Auth alone is NOT enough to use the panel — the signed-in
 * user's id must also exist in `admin_users` (checked here via the
 * service-role client, never via a client-visible RLS policy). Call this
 * at the top of every protected page AND every server action that mutates
 * data — React's `cache()` means calling it more than once per request is
 * free, so there's no reason to skip it anywhere "because a parent layout
 * already checked."
 */
export const verifyAdminSession = cache(async (): Promise<AdminSession> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const service = createServiceClient();
  const { data: admin } = await service
    .from("admin_users")
    .select("display_name")
    .eq("user_id", user.id)
    .maybeSingle();

  if (!admin) {
    redirect("/login?error=not_admin");
  }

  return {
    userId: user.id,
    email: user.email ?? null,
    displayName: admin.display_name,
  };
});

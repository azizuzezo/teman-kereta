"use client";

import { createBrowserClient } from "@supabase/ssr";

/** For Client Components only — the login form's sign-in/sign-out calls. */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

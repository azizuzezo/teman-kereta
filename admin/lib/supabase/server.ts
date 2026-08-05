import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

/**
 * A Supabase client bound to the current request's cookies, running with
 * the anon key + the signed-in user's session (subject to RLS). Use this to
 * find out *who* is signed in — never for privileged reference-data writes,
 * which go through `createServiceClient` instead (see service.ts).
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // Called from a Server Component render, where cookies can't be
            // written — harmless as long as proxy.ts also refreshes the
            // session (it does), per the Supabase SSR guide.
          }
        },
      },
    }
  );
}

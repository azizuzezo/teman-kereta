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
      // supabase-js defaults to the `cross-fetch` polyfill outside a browser,
      // which conflicts with Cloudflare Workers' native fetch (surfaces as a
      // generic "Connection closed" error, not an obvious fetch failure) —
      // forcing the native global fetch here bypasses that polyfill. Must be
      // bound to globalThis: passing the bare `fetch` reference loses its
      // internal `this` and breaks the exact same way under Node's own
      // undici-based fetch, not just avoiding the Workers issue.
      global: { fetch: globalThis.fetch.bind(globalThis) },
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

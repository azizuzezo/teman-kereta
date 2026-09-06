import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

/**
 * Optimistic check only (see Next.js's auth guide) — refreshes the Supabase
 * session cookie on every request and redirects unauthenticated visitors to
 * /login. This is NOT the real authorization boundary: whether the signed-in
 * user is actually an admin (member of `admin_users`) is checked server-side
 * in lib/dal.ts on every protected page and server action, since that check
 * needs the service-role client and shouldn't run on every prefetched route.
 *
 * Deliberately kept as `middleware.ts` (not renamed to Next.js 16's `proxy.ts`
 * convention): `proxy.ts` is hard-locked to the `nodejs` runtime with no way
 * to opt into `edge`, which Cloudflare's OpenNext adapter doesn't support
 * ("Node.js middleware is not currently supported"). This file only touches
 * cookies and a fetch-based Supabase client — genuinely edge-compatible —
 * so staying on the `middleware` convention keeps that option open.
 */
export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      // See lib/supabase/server.ts — must be bound to globalThis, not a bare
      // reference, or this breaks identically under Node's own fetch too.
      global: { fetch: globalThis.fetch.bind(globalThis) },
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const pathname = request.nextUrl.pathname;
  const isPublicRoute =
    pathname === "/login" ||
    pathname === "/privacy" ||
    pathname === "/confirm";

  if (!user && !isPublicRoute) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};

import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Without this, Turbopack's dev-mode bundling of @supabase/ssr's fetch
  // usage causes every server-side Supabase Auth call (login, session
  // refresh in middleware) to fail with a generic "Connection closed" error
  // — reproduced identically with the global.fetch override removed, and
  // confirmed absent when calling the exact same client construction via
  // plain `node` outside Next.js entirely. Excluding these packages from
  // bundling lets Node's own module resolution handle them unmodified.
  serverExternalPackages: ["@supabase/ssr", "@supabase/supabase-js"],
  // The default 1MB Server Action body limit is far too small for the APK
  // uploads on /releases (releases bucket allows up to 200MB, see
  // supabase/migrations/20260822103000_app_releases.sql). The 'releases'
  // storage bucket has no authenticated-insert policy, so uploads go
  // through the createRelease server action (service-role client) instead
  // of a client-direct-to-storage upload.
  experimental: {
    serverActions: {
      bodySizeLimit: "250mb",
    },
  },
};

export default nextConfig;

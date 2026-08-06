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
};

export default nextConfig;

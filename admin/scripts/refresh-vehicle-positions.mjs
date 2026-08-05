// Calls public.refresh_estimated_vehicle_positions() on a fixed interval,
// keeping public.vehicle_positions populated with schedule-based estimated
// positions (source='estimated') so a `local_supabase` Flutter client has
// something real to stream via Supabase Realtime. See the migration
// `20260805170000_estimated_vehicle_positions.sql` for what the function
// actually computes, and its doc comment for why this lives here instead of
// a second, separate GTFS backend/schema.
//
// This process only produces a visible effect when TRANSIT_PROVIDER=
// local_supabase in the Flutter app's .env — under TRANSIT_PROVIDER=gtfs
// (the current default) nothing reads public.vehicle_positions.
//
// Reads admin/.env.local itself, same as bootstrap-admin.mjs — no dotenv
// dependency. Runs until killed (Ctrl+C); does not daemonize itself.
//
// Usage: node scripts/refresh-vehicle-positions.mjs [poll_seconds]
import { readFileSync } from "node:fs";
import { createClient } from "@supabase/supabase-js";

function loadEnvLocal() {
  const text = readFileSync(new URL("../.env.local", import.meta.url), "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    env[trimmed.slice(0, eq)] = trimmed.slice(eq + 1);
  }
  return env;
}

async function tick(supabase) {
  const startedAt = new Date().toISOString();
  const { data, error } = await supabase.rpc(
    "refresh_estimated_vehicle_positions",
  );
  if (error) {
    console.error(`[${startedAt}] refresh failed:`, error.message);
    return;
  }
  console.log(`[${startedAt}] refreshed ${data} estimated vehicle position(s)`);
}

async function main() {
  const pollSeconds = Number.parseInt(process.argv[2] ?? "", 10) || 20;
  const env = loadEnvLocal();
  const supabase = createClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  console.log(
    `Polling refresh_estimated_vehicle_positions() every ${pollSeconds}s against ${env.NEXT_PUBLIC_SUPABASE_URL}. Ctrl+C to stop.`,
  );

  let stopping = false;
  process.on("SIGINT", () => {
    stopping = true;
  });

  while (!stopping) {
    await tick(supabase);
    await new Promise((resolve) => setTimeout(resolve, pollSeconds * 1000));
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

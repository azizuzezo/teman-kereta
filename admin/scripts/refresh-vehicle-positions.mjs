// Calls both public.refresh_estimated_vehicle_positions() and
// public.refresh_crowd_vehicle_positions() on a fixed interval, keeping
// public.vehicle_positions populated with schedule-based estimated
// positions (source='estimated') AND real rider-reported crowd-sourced
// positions (source='crowd_sourced', folded from public.
// crowd_position_reports — see `20260806090000_crowd_sourced_positions.sql`
// for what that function computes and its retention behavior). See
// `20260805170000_estimated_vehicle_positions.sql` for the estimated
// function, and its doc comment for why this lives here instead of a
// second, separate GTFS backend/schema.
//
// Unlike the estimated-only positions, the crowd-sourced ones DO reach
// `TRANSIT_PROVIDER=gtfs` (the current default) too, via
// HybridTransitRealtimeProvider — see provider_registry.dart. The
// schedule-estimated positions still only reach `local_supabase`.
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

  const estimated = await supabase.rpc("refresh_estimated_vehicle_positions");
  if (estimated.error) {
    console.error(`[${startedAt}] estimated refresh failed:`, estimated.error.message);
  } else {
    console.log(`[${startedAt}] refreshed ${estimated.data} estimated vehicle position(s)`);
  }

  const crowd = await supabase.rpc("refresh_crowd_vehicle_positions");
  if (crowd.error) {
    console.error(`[${startedAt}] crowd refresh failed:`, crowd.error.message);
  } else {
    console.log(`[${startedAt}] refreshed ${crowd.data} crowd-sourced vehicle position(s)`);
  }
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
    `Polling refresh_estimated_vehicle_positions() + refresh_crowd_vehicle_positions() every ${pollSeconds}s against ${env.NEXT_PUBLIC_SUPABASE_URL}. Ctrl+C to stop.`,
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

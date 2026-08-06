// One-off recovery script: the 2026-08-06 community-conversion GTFS import
// (see ENGINEERING.md) had empty stop_lat/stop_lon for every station, and
// Number("") evaluates to 0 in JS rather than throwing, so the import
// silently wrote (0,0) over every real station's coordinates. This
// restores them from the old bundled dev feed's real (if approximate,
// per its own stop_desc) coordinates, without touching anything else the
// new import correctly updated (facilities, names, station_lines, etc).
// Usage: npx tsx scripts/restore-coordinates-oneoff.mts
import { readFileSync } from "node:fs";
import { createClient } from "@supabase/supabase-js";
import { parseStops } from "../lib/gtfs/parser";

function loadEnvLocal() {
  const text = readFileSync(new URL("../.env.local", import.meta.url), "utf8");
  const env: Record<string, string> = {};
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    env[trimmed.slice(0, eq)] = trimmed.slice(eq + 1);
  }
  return env;
}

async function main() {
  const [oldStopsPath] = process.argv.slice(2);
  if (!oldStopsPath) {
    console.error("Usage: npx tsx scripts/restore-coordinates-oneoff.mts <path-to-old-stops.txt>");
    process.exit(1);
  }
  const csvText = readFileSync(oldStopsPath, "utf8");
  const stops = parseStops(csvText);
  console.log(`Parsed ${stops.length} stops from old feed`);

  const env = loadEnvLocal();
  const supabase = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let updated = 0;
  for (const stop of stops) {
    if (stop.latitude === 0 && stop.longitude === 0) {
      console.log(`Skipping ${stop.stopId} — old feed also has 0,0`);
      continue;
    }
    const { error } = await supabase
      .from("stations")
      .update({ latitude: stop.latitude, longitude: stop.longitude })
      .eq("code", stop.stopId);
    if (error) {
      console.error(`FAILED ${stop.stopId}: ${error.message}`);
      continue;
    }
    updated += 1;
  }
  console.log(`Restored coordinates for ${updated} stations`);
}

main().catch((error) => {
  console.error("FAILED:", error);
  process.exit(1);
});

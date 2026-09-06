// One-off standalone script to import the real bundled KRL Jabodetabek GTFS
// feed into the hosted reference schema, bypassing the Next.js HTTP layer
// entirely (see ENGINEERING.md's admin-panel-hosting notes for why: a
// "Connection closed" error reproduces for every Supabase Auth/DB call made
// from within Next.js's own local server process on this machine, in both
// dev and production mode, while the exact same client construction called
// from plain Node succeeds instantly — isolated to Next.js's local server
// runtime, not the code, not Supabase, and not the deployed Cloudflare
// Worker). This reuses the same `importGtfsFeed` algorithm as
// admin/lib/gtfs/importer.ts (which can't be imported directly here — it
// has `import "server-only"` at the top, which unconditionally throws
// outside Next.js's own bundler substitution) via the same underlying
// parser/calendar helpers, which have no such guard.
//
// Usage: npx tsx scripts/import-real-gtfs.mts <path-to-gtfs.zip> <operator-id> <window-days>
import { readFileSync } from "node:fs";
import JSZip from "jszip";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  parseStops,
  parseRoutes,
  parseTrips,
  parseStopTimes,
  parseCalendar,
  parseCalendarDates,
  parseStationDescription,
} from "../lib/gtfs/parser";
import { ServiceCalendar, dateWindow, routeTypeToTransportMode } from "../lib/gtfs/calendar";

// A newer feed can use different route_id conventions than whatever was
// imported before it under the same operator — upserts key on
// (operator_id, code), so a mismatched code creates a duplicate line
// instead of updating the existing one. Remap known renames here rather
// than silently duplicating; verified against the live hosted `lines` table
// before this script's first run against the KRL community-conversion feed
// (2026-08-06): RANGKASBITUNG/TANJUNG_PRIOK are that feed's names for the
// already-hosted RANGKAS/PRIOK lines.
const ROUTE_ID_REMAP: Record<string, string> = {
  RANGKASBITUNG: "RANGKAS",
  TANJUNG_PRIOK: "PRIOK",
};
function canonicalRouteCode(routeId: string): string {
  return ROUTE_ID_REMAP[routeId] ?? routeId;
}

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

const REQUIRED_FILES = ["stops.txt", "routes.txt", "trips.txt", "stop_times.txt"];
const HEX_COLOR = /^[0-9A-Fa-f]{6}$/;

async function extractGtfsFiles(zipBytes: ArrayBuffer): Promise<Record<string, string>> {
  const zip = await JSZip.loadAsync(zipBytes);
  const files: Record<string, string> = {};
  for (const [path, entry] of Object.entries(zip.files)) {
    if (entry.dir) continue;
    const name = path.split("/").pop();
    if (!name) continue;
    files[name] = await entry.async("string");
  }
  return files;
}

function secondsToIntervalLiteral(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${hours}:${pad(minutes)}:${pad(secs)}`;
}

async function upsertInChunks(
  supabase: SupabaseClient,
  table: string,
  rows: Record<string, unknown>[],
  onConflict: string,
  chunkSize = 500,
) {
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    const { error } = await supabase.from(table).upsert(chunk as never[], { onConflict });
    if (error) throw new Error(`Gagal menyimpan ke ${table}: ${error.message}`);
    console.log(`  upserted ${table} ${i + chunk.length}/${rows.length}`);
  }
}

async function main() {
  const [zipPath, operatorId, windowDaysArg] = process.argv.slice(2);
  if (!zipPath || !operatorId) {
    console.error(
      "Usage: npx tsx scripts/import-real-gtfs.mts <path-to-gtfs.zip> <operator-id> [window-days=7]",
    );
    process.exit(1);
  }
  const windowDays = Number.parseInt(windowDaysArg ?? "", 10) || 7;

  const env = loadEnvLocal();
  const supabase = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  console.log(`Importing ${zipPath} for operator ${operatorId}, window ${windowDays} days...`);
  const zipBytes = readFileSync(zipPath);
  const files = await extractGtfsFiles(zipBytes.buffer.slice(zipBytes.byteOffset, zipBytes.byteOffset + zipBytes.byteLength));

  const missing = REQUIRED_FILES.filter((name) => !files[name]);
  if (missing.length > 0) throw new Error(`Berkas GTFS wajib tidak ada: ${missing.join(", ")}.`);

  const feed = {
    stops: parseStops(files["stops.txt"]),
    routes: parseRoutes(files["routes.txt"]),
    trips: parseTrips(files["trips.txt"]),
    stopTimes: parseStopTimes(files["stop_times.txt"]),
    calendar: files["calendar.txt"] ? parseCalendar(files["calendar.txt"]) : [],
    calendarDates: files["calendar_dates.txt"] ? parseCalendarDates(files["calendar_dates.txt"]) : [],
  };
  console.log(
    `Parsed: ${feed.stops.length} stops, ${feed.routes.length} routes, ${feed.trips.length} trips, ${feed.stopTimes.length} stop_times`,
  );

  // This feed's calendar.txt is bounded to 2025-02-01..2025-12-31 — a real
  // KRL timetable doesn't stop existing at year end, so at the user's
  // explicit direction this import treats the weekday pattern as
  // open-ended rather than skipping every trip as "expired." Only affects
  // this script's date-bound check (weekday matching and
  // calendar_dates.txt exceptions still apply normally) — the general
  // ServiceCalendar semantics in calendar.ts are untouched for feeds whose
  // start/end dates are meant to matter.
  const openEndedCalendar = feed.calendar.map((entry) => ({
    ...entry,
    startDate: "2000-01-01",
    endDate: "2099-12-31",
  }));
  const calendar = new ServiceCalendar(openEndedCalendar, feed.calendarDates);
  const startDateIso = new Date().toISOString().slice(0, 10);
  const days = dateWindow(startDateIso, windowDays);

  console.log("Upserting stations...");
  const { data: existingStations } = await supabase
    .from("stations")
    .select("code, latitude, longitude");
  const existingCoordsMap = new Map(
    existingStations?.map((s) => [s.code, { latitude: s.latitude, longitude: s.longitude }]) ?? [],
  );

  await upsertInChunks(
    supabase,
    "stations",
    feed.stops.map((stop) => {
      const existing = existingCoordsMap.get(stop.stopId);
      const lat = stop.latitude !== 0 ? stop.latitude : (existing?.latitude ?? 0);
      const lon = stop.longitude !== 0 ? stop.longitude : (existing?.longitude ?? 0);
      return {
        code: stop.stopId,
        name: stop.name,
        latitude: lat,
        longitude: lon,
        wheelchair_accessible:
          stop.wheelchairBoarding === 1 ? true : stop.wheelchairBoarding === 2 ? false : null,
        facilities: parseStationDescription(stop.description),
      };
    }),
    "code",
  );
  const { data: stationRows, error: stationError } = await supabase
    .from("stations")
    .select("id, code")
    .in("code", feed.stops.map((s) => s.stopId));
  if (stationError) throw new Error(`Gagal membaca stasiun: ${stationError.message}`);
  const stationIdByCode = new Map(stationRows.map((r) => [r.code, r.id as string]));

  console.log("Upserting lines...");
  await upsertInChunks(
    supabase,
    "lines",
    feed.routes.map((route) => ({
      operator_id: operatorId,
      code: canonicalRouteCode(route.routeId),
      name: route.longName ?? route.shortName ?? route.routeId,
      transport_mode: routeTypeToTransportMode(route.routeType),
      color: route.color && HEX_COLOR.test(route.color) ? `#${route.color}` : null,
      text_color: route.textColor && HEX_COLOR.test(route.textColor) ? `#${route.textColor}` : null,
    })),
    "operator_id,code",
  );
  const { data: lineRows, error: lineError } = await supabase
    .from("lines")
    .select("id, code")
    .eq("operator_id", operatorId)
    .in("code", feed.routes.map((r) => canonicalRouteCode(r.routeId)));
  if (lineError) throw new Error(`Gagal membaca jalur: ${lineError.message}`);
  const lineIdByCode = new Map(lineRows.map((r) => [r.code, r.id as string]));

  const stopTimesByTripId = new Map<string, typeof feed.stopTimes>();
  for (const stopTime of feed.stopTimes) {
    const list = stopTimesByTripId.get(stopTime.tripId) ?? [];
    list.push(stopTime);
    stopTimesByTripId.set(stopTime.tripId, list);
  }

  // station_lines (station_id, line_id, stop_order) has existed in the
  // schema since the initial migration but was never populated by either
  // importer — GtfsStaticScheduleProvider/SupabaseTransitProvider's
  // Station.lineIds has consequently always come back empty. One canonical
  // trip per route (the one with the most stops, as a representative
  // ordering — a route's reverse-direction trips cover the same physical
  // stations, just reversed, so this is enough to establish "which stations
  // belong to this line, in order" without needing both directions).
  console.log("Deriving station_lines ordering from the longest trip per route...");
  const canonicalTripByRoute = new Map<string, (typeof feed.trips)[number]>();
  for (const trip of feed.trips) {
    const stopCount = stopTimesByTripId.get(trip.tripId)?.length ?? 0;
    const existing = canonicalTripByRoute.get(trip.routeId);
    const existingCount = existing ? stopTimesByTripId.get(existing.tripId)?.length ?? 0 : -1;
    if (stopCount > existingCount) canonicalTripByRoute.set(trip.routeId, trip);
  }
  const stationLineRows: { station_id: string; line_id: string; stop_order: number }[] = [];
  for (const [routeId, trip] of canonicalTripByRoute) {
    const lineId = lineIdByCode.get(canonicalRouteCode(routeId));
    if (!lineId) continue;
    const orderedStopTimes = [...(stopTimesByTripId.get(trip.tripId) ?? [])].sort(
      (a, b) => a.stopSequence - b.stopSequence,
    );
    orderedStopTimes.forEach((stopTime, index) => {
      const stationId = stationIdByCode.get(stopTime.stopId);
      if (!stationId) return;
      stationLineRows.push({ station_id: stationId, line_id: lineId, stop_order: index + 1 });
    });
  }
  await upsertInChunks(supabase, "station_lines", stationLineRows, "station_id,line_id");
  console.log(`Upserted station_lines: ${stationLineRows.length} rows across ${canonicalTripByRoute.size} lines`);

  type TripInsert = {
    external_trip_id: string;
    line_id: string;
    service_id: string;
    headsign: string;
    trip_number: string | null;
    data_source: "gtfs";
    service_date: string;
  };
  const tripInserts: TripInsert[] = [];
  const tripKeyToStopTimes = new Map<string, typeof feed.stopTimes>();

  for (const trip of feed.trips) {
    const lineId = lineIdByCode.get(canonicalRouteCode(trip.routeId));
    if (!lineId) continue;
    for (const day of days) {
      if (!calendar.runsOn(trip.serviceId, day)) continue;
      const key = `${trip.tripId}::${day}`;
      tripInserts.push({
        external_trip_id: trip.tripId,
        line_id: lineId,
        service_id: trip.serviceId,
        headsign: trip.headsign ?? trip.tripId,
        trip_number: trip.tripShortName,
        data_source: "gtfs",
        service_date: day,
      });
      tripKeyToStopTimes.set(key, stopTimesByTripId.get(trip.tripId) ?? []);
    }
  }
  console.log(`Expanded to ${tripInserts.length} (trip, service_date) instances over ${days.length} days`);

  const tripIdByKey = new Map<string, string>();
  for (let i = 0; i < tripInserts.length; i += 500) {
    const chunk = tripInserts.slice(i, i + 500);
    const { data: rpcRows, error: rpcError } = await supabase.rpc("import_gtfs_trips", { p_trips: chunk });
    if (rpcError) throw new Error(`Gagal mengimpor trip: ${rpcError.message}`);
    for (const row of rpcRows as { out_external_trip_id: string; out_service_date: string; out_id: string }[]) {
      tripIdByKey.set(`${row.out_external_trip_id}::${row.out_service_date}`, row.out_id);
    }
    console.log(`  imported trips ${i + chunk.length}/${tripInserts.length}`);
  }

  type StopTimeInsert = {
    trip_id: string;
    station_id: string;
    stop_sequence: number;
    scheduled_arrival: string;
    scheduled_departure: string;
  };
  const stopTimeInserts: StopTimeInsert[] = [];
  for (const [key, stopTimes] of tripKeyToStopTimes.entries()) {
    const tripId = tripIdByKey.get(key);
    if (!tripId) continue;
    for (const stopTime of stopTimes) {
      const stationId = stationIdByCode.get(stopTime.stopId);
      if (!stationId) continue;
      stopTimeInserts.push({
        trip_id: tripId,
        station_id: stationId,
        stop_sequence: stopTime.stopSequence,
        scheduled_arrival: secondsToIntervalLiteral(stopTime.arrivalSeconds),
        scheduled_departure: secondsToIntervalLiteral(stopTime.departureSeconds),
      });
    }
  }
  console.log(`Prepared ${stopTimeInserts.length} stop_time rows`);

  const importedTripIds = [...new Set(stopTimeInserts.map((s) => s.trip_id))];
  console.log(`Clearing stale stop_times for ${importedTripIds.length} trips being reimported...`);
  for (let i = 0; i < importedTripIds.length; i += 200) {
    const chunk = importedTripIds.slice(i, i + 200);
    const { error: deleteError } = await supabase.from("stop_times").delete().in("trip_id", chunk);
    if (deleteError) throw new Error(`Gagal membersihkan jadwal lama: ${deleteError.message}`);
  }

  console.log("Upserting stop_times...");
  await upsertInChunks(supabase, "stop_times", stopTimeInserts, "trip_id,stop_sequence");

  console.log("Done:", {
    stopCount: feed.stops.length,
    routeCount: feed.routes.length,
    tripCount: feed.trips.length,
    serviceDaysExpanded: days.length,
    tripInstancesImported: tripInserts.length,
    stopTimeRowsImported: stopTimeInserts.length,
  });
}

main().catch((error) => {
  console.error("IMPORT FAILED:", error);
  process.exit(1);
});

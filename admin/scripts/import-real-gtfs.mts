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
// Usage:
//   npx tsx scripts/import-real-gtfs.mts <path-to-gtfs.zip> <operator-id> [window-days=7] [--respect-calendar]
//       [--schedule-set <nama>] [--start-date YYYY-MM-DD]
// --schedule-set menaruh perjalanan di set jadwal tersendiri (mis. gapeka2026) yang tidak terlihat pengguna sampai
// diaktifkan dengan tombol di halaman Jadwal admin. Tanpa opsi ini perjalanan masuk set `lama` (langsung terlihat).
// --start-date memulai jendela dari tanggal itu, bukan hari ini (mis. 2026-12-01 untuk GAPEKA 2026).
//   npx tsx scripts/import-real-gtfs.mts <path-to-gtfs.zip> [window-days=7] --operator-map KAI=<uuid>,KCI=<uuid> [--respect-calendar]
// With --operator-map each route goes to the operator mapped from its routes.txt `agency_id` (a feed mixing KAI
// intercity and KCI commuter routes); without it every route goes to the single positional <operator-id>.
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

const USAGE = [
  "Usage: npx tsx scripts/import-real-gtfs.mts <path-to-gtfs.zip> <operator-id> [window-days=7] [--respect-calendar]",
  "   or: npx tsx scripts/import-real-gtfs.mts <path-to-gtfs.zip> [window-days=7] --operator-map KAI=<uuid>,KCI=<uuid> [--respect-calendar]",
].join("\n");
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function usageError(message?: string): never {
  if (message) console.error(`Error: ${message}`);
  console.error(USAGE);
  process.exit(1);
}

/** `KAI=<uuid>,KCI=<uuid>` -> Map(agency_id -> operator uuid). */
function parseOperatorMap(value: string): Map<string, string> {
  const map = new Map<string, string>();
  for (const pair of value.split(",").map((p) => p.trim()).filter(Boolean)) {
    const eq = pair.indexOf("=");
    const agency = eq === -1 ? "" : pair.slice(0, eq).trim();
    const operator = eq === -1 ? "" : pair.slice(eq + 1).trim();
    if (!agency || !operator) usageError(`--operator-map entry "${pair}" must look like AGENCY=<operator-uuid>.`);
    if (!UUID.test(operator)) usageError(`--operator-map: "${operator}" (agency ${agency}) is not a UUID.`);
    if (map.has(agency)) usageError(`--operator-map: agency ${agency} is mapped twice.`);
    map.set(agency, operator);
  }
  if (map.size === 0) usageError("--operator-map is empty.");
  return map;
}

async function main() {
  const rawArgs = process.argv.slice(2);
  // --respect-calendar: honour calendar.txt start/end dates (needed for a feed that starts on a future date, e.g.
  // GAPEKA 2026 from 2026-12-01). Without it the script keeps its original open-ended behaviour (see below).
  let respectCalendar = false;
  let operatorMapArg: string | null = null;
  let scheduleSet = "lama";
  let scheduleSetExplicit = false;
  let startDateArg: string | null = null;
  const positional: string[] = [];
  for (let i = 0; i < rawArgs.length; i += 1) {
    const arg = rawArgs[i];
    if (arg === "--respect-calendar") {
      respectCalendar = true;
    } else if (arg === "--operator-map") {
      const next = rawArgs[i + 1];
      if (next === undefined || next.startsWith("--")) usageError("--operator-map needs a value.");
      operatorMapArg = next;
      i += 1;
    } else if (arg.startsWith("--operator-map=")) {
      operatorMapArg = arg.slice("--operator-map=".length);
    } else if (arg === "--schedule-set" || arg.startsWith("--schedule-set=")) {
      const value = arg === "--schedule-set" ? rawArgs[(i += 1)] : arg.slice("--schedule-set=".length);
      if (value === undefined || value.startsWith("--") || !/^[a-z0-9][a-z0-9_-]{0,39}$/.test(value)) {
        usageError("--schedule-set needs a name like gapeka2026 (lowercase letters, digits, - or _).");
      }
      scheduleSet = value;
      scheduleSetExplicit = true;
    } else if (arg === "--start-date" || arg.startsWith("--start-date=")) {
      const value = arg === "--start-date" ? rawArgs[(i += 1)] : arg.slice("--start-date=".length);
      if (value === undefined || !/^\d{4}-\d{2}-\d{2}$/.test(value) || Number.isNaN(Date.parse(value))) {
        usageError("--start-date needs a date like 2026-12-01.");
      }
      startDateArg = value;
    } else if (arg.startsWith("--")) {
      console.warn(`Ignoring unknown option ${arg}.`); // previous behaviour: unknown --flags were ignored
    } else {
      positional.push(arg);
    }
  }
  const operatorMap = operatorMapArg !== null ? parseOperatorMap(operatorMapArg) : null;

  let zipPath: string | undefined;
  let operatorId: string | null = null;
  let windowDaysArg: string | undefined;
  if (operatorMap) {
    if (positional.length > 2 || (positional[1] !== undefined && !/^\d+$/.test(positional[1]))) {
      usageError("With --operator-map do not pass a positional <operator-id>; use <path-to-gtfs.zip> [window-days].");
    }
    [zipPath, windowDaysArg] = positional;
  } else {
    [zipPath, operatorId = null, windowDaysArg] = positional;
    if (!operatorId) usageError();
  }
  if (!zipPath) usageError();
  const windowDays = Number.parseInt(windowDaysArg ?? "", 10) || 7;

  console.log(
    `Importing ${zipPath} for ${
      operatorMap
        ? `operators ${[...operatorMap].map(([agency, id]) => `${agency}=${id}`).join(", ")}`
        : `operator ${operatorId}`
    }, window ${windowDays} days...`,
  );
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
    `Parsed: ${feed.stops.length} stops, ${feed.routes.length} routes, ${feed.trips.length} trips, ${
      feed.stopTimes.length
    } stop_times (${feed.stopTimes.filter((st) => st.isEstimated).length} estimated)`,
  );

  // Resolve every route's operator before touching the database, so a
  // missing --operator-map entry fails without writing anything.
  const operatorIdByRouteId = new Map<string, string>();
  const unmapped = new Set<string>();
  for (const route of feed.routes) {
    if (!operatorMap) {
      operatorIdByRouteId.set(route.routeId, operatorId as string);
      continue;
    }
    const agency = route.agencyId ?? null;
    const mapped = agency !== null ? operatorMap.get(agency) : undefined;
    if (!mapped) {
      unmapped.add(agency === null ? `(route ${route.routeId} has no agency_id)` : agency);
      continue;
    }
    operatorIdByRouteId.set(route.routeId, mapped);
  }
  if (unmapped.size > 0) {
    throw new Error(
      `--operator-map has no operator for agency_id: ${[...unmapped].join(", ")}. ` +
        `Mapped: ${[...(operatorMap?.keys() ?? [])].join(", ")}.`,
    );
  }
  const routeOperator = (routeId: string): string => {
    const id = operatorIdByRouteId.get(routeId);
    if (!id) throw new Error(`Route ${routeId} is not in routes.txt.`);
    return id;
  };
  const lineKey = (operator: string, code: string) => `${operator}::${code}`;

  const env = loadEnvLocal();
  const supabase = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // This feed's calendar.txt is bounded to 2025-02-01..2025-12-31 — a real
  // KRL timetable doesn't stop existing at year end, so at the user's
  // explicit direction this import treats the weekday pattern as
  // open-ended rather than skipping every trip as "expired." Only affects
  // this script's date-bound check (weekday matching and
  // calendar_dates.txt exceptions still apply normally) — the general
  // ServiceCalendar semantics in calendar.ts are untouched for feeds whose
  // start/end dates are meant to matter.
  const openEndedCalendar = respectCalendar
    ? feed.calendar
    : feed.calendar.map((entry) => ({
        ...entry,
        startDate: "2000-01-01",
        endDate: "2099-12-31",
      }));
  const calendar = new ServiceCalendar(openEndedCalendar, feed.calendarDates);
  console.log(respectCalendar ? "Calendar: start/end dates respected" : "Calendar: open-ended (start/end dates ignored)");
  const todayIso = new Date().toISOString().slice(0, 10);
  const startDateIso = startDateArg ?? todayIso;
  const days = dateWindow(startDateIso, windowDays);
  console.log(`Window: ${days[0]} .. ${days[days.length - 1]} (${days.length} days)`);

  // Feed yang baru berlaku di masa depan dan masuk ke set `lama` akan langsung terlihat pengguna begitu tanggalnya
  // tiba, tanpa tombol pergantian. Minta set eksplisit supaya itu tidak terjadi karena lupa opsi.
  const earliestStart = feed.calendar.map((entry) => entry.startDate).sort()[0];
  if (respectCalendar && earliestStart && earliestStart > todayIso && !scheduleSetExplicit) {
    throw new Error(
      `Feed ini baru berlaku mulai ${earliestStart} (masa depan). Tambahkan --schedule-set <nama> (mis. gapeka2026) ` +
        `agar tidak langsung terlihat pengguna, atau --schedule-set lama bila memang disengaja.`,
    );
  }
  if (scheduleSet !== "lama") {
    // Fungsi import lama mengabaikan kolom yang tidak dikenal, sehingga tanpa migrasi saklar perjalanan akan diam-diam
    // masuk ke set `lama` dan langsung terlihat. Pastikan migrasinya sudah ada sebelum menulis apa pun.
    const { error: readyError } = await supabase.rpc("get_schedule_status");
    if (readyError) {
      throw new Error(
        `Saklar jadwal belum ada di database (${readyError.message}). Terapkan migrasi 20261122090000_schedule_switch.sql dulu.`,
      );
    }
  }
  console.log(`Schedule set: ${scheduleSet}${scheduleSet === "lama" ? " (terlihat langsung)" : " (tersembunyi sampai diaktifkan)"}`);

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
      operator_id: routeOperator(route.routeId),
      code: canonicalRouteCode(route.routeId),
      name: route.longName ?? route.shortName ?? route.routeId,
      transport_mode: routeTypeToTransportMode(route.routeType),
      color: route.color && HEX_COLOR.test(route.color) ? `#${route.color}` : null,
      text_color: route.textColor && HEX_COLOR.test(route.textColor) ? `#${route.textColor}` : null,
    })),
    "operator_id,code",
  );
  // lines are unique on (operator_id, code): look them up per operator.
  const lineIdByKey = new Map<string, string>();
  for (const operator of new Set(operatorIdByRouteId.values())) {
    const codes = feed.routes
      .filter((r) => routeOperator(r.routeId) === operator)
      .map((r) => canonicalRouteCode(r.routeId));
    const { data: lineRows, error: lineError } = await supabase
      .from("lines")
      .select("id, code")
      .eq("operator_id", operator)
      .in("code", codes);
    if (lineError) throw new Error(`Gagal membaca jalur: ${lineError.message}`);
    for (const r of lineRows) lineIdByKey.set(lineKey(operator, r.code), r.id as string);
  }
  const lineIdForRoute = (routeId: string): string | undefined => {
    const operator = operatorIdByRouteId.get(routeId);
    return operator ? lineIdByKey.get(lineKey(operator, canonicalRouteCode(routeId))) : undefined;
  };

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
    const lineId = lineIdForRoute(routeId);
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
    schedule_set?: string;
  };
  const tripInserts: TripInsert[] = [];
  const tripKeyToStopTimes = new Map<string, typeof feed.stopTimes>();

  for (const trip of feed.trips) {
    const lineId = lineIdForRoute(trip.routeId);
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
        // Hanya dikirim untuk set bukan-bawaan, supaya import biasa tetap jalan sebelum migrasi saklar diterapkan.
        ...(scheduleSet !== "lama" ? { schedule_set: scheduleSet } : {}),
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
    is_estimated: boolean;
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
        is_estimated: stopTime.isEstimated,
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

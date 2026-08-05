import "server-only";

import JSZip from "jszip";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  parseStops,
  parseRoutes,
  parseTrips,
  parseStopTimes,
  parseCalendar,
  parseCalendarDates,
} from "./parser";
import { ServiceCalendar, dateWindow, routeTypeToTransportMode } from "./calendar";
import type { GtfsFeed } from "./types";

const REQUIRED_FILES = ["stops.txt", "routes.txt", "trips.txt", "stop_times.txt"];
const HEX_COLOR = /^[0-9A-Fa-f]{6}$/;

export type GtfsImportSummary = {
  stopCount: number;
  routeCount: number;
  tripCount: number;
  serviceDaysExpanded: number;
  tripInstancesImported: number;
  stopTimeRowsImported: number;
};

export async function extractGtfsFiles(
  zipBytes: ArrayBuffer
): Promise<Record<string, string>> {
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

export function parseGtfsFeed(files: Record<string, string>): GtfsFeed {
  const missing = REQUIRED_FILES.filter((name) => !files[name]);
  if (missing.length > 0) {
    throw new Error(`Berkas GTFS wajib tidak ada: ${missing.join(", ")}.`);
  }
  if (!files["calendar.txt"] && !files["calendar_dates.txt"]) {
    throw new Error(
      "Feed GTFS harus memiliki calendar.txt dan/atau calendar_dates.txt."
    );
  }

  return {
    stops: parseStops(files["stops.txt"]),
    routes: parseRoutes(files["routes.txt"]),
    trips: parseTrips(files["trips.txt"]),
    stopTimes: parseStopTimes(files["stop_times.txt"]),
    calendar: files["calendar.txt"] ? parseCalendar(files["calendar.txt"]) : [],
    calendarDates: files["calendar_dates.txt"]
      ? parseCalendarDates(files["calendar_dates.txt"])
      : [],
  };
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
  chunkSize = 500
) {
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    // The generated Database types aren't wired up for this client (see
    // createServiceClient), so supabase-js falls back to a generic `any`
    // row shape here — cast away the excess-property check that trips up
    // on that generic shape rather than a real table row type.
    const { error } = await supabase
      .from(table)
      .upsert(chunk as never[], { onConflict });
    if (error) {
      throw new Error(`Gagal menyimpan ke ${table}: ${error.message}`);
    }
  }
}

/**
 * Imports a GTFS Schedule (static) feed into the real reference schema
 * (operators/lines/stations/trips/stop_times) — NOT the same thing as the
 * Flutter app's local GTFS importer, which caches a feed on-device. This
 * one materializes the recurring calendar.txt/calendar_dates.txt pattern
 * into concrete (trip, service_date) rows for a bounded window, since
 * `public.trips.service_date` is a concrete date column, not a recurring
 * pattern — see docs/backend-local.md's "Catatan waktu GTFS". A large
 * window multiplies row counts fast (trips × days), so this is capped by
 * the caller's `windowDays` input, not unbounded.
 *
 * Stations are upserted by `code` (GTFS `stop_id`), lines by
 * `(operator_id, code)` (GTFS `route_id`) under the caller-selected
 * `operatorId` — GTFS itself has no concept of this schema's operator, so
 * the admin must already have created one to attach the feed to.
 */
export async function importGtfsFeed(params: {
  supabase: SupabaseClient;
  operatorId: string;
  zipBytes: ArrayBuffer;
  startDateIso: string;
  windowDays: number;
}): Promise<GtfsImportSummary> {
  const { supabase, operatorId, zipBytes, startDateIso, windowDays } = params;

  const files = await extractGtfsFiles(zipBytes);
  const feed = parseGtfsFeed(files);
  const calendar = new ServiceCalendar(feed.calendar, feed.calendarDates);
  const days = dateWindow(startDateIso, windowDays);

  // 1. Stations, upserted by their natural GTFS key (stop_id -> code).
  await upsertInChunks(
    supabase,
    "stations",
    feed.stops.map((stop) => ({
      code: stop.stopId,
      name: stop.name,
      latitude: stop.latitude,
      longitude: stop.longitude,
    })),
    "code"
  );
  const { data: stationRows, error: stationError } = await supabase
    .from("stations")
    .select("id, code")
    .in(
      "code",
      feed.stops.map((s) => s.stopId)
    );
  if (stationError) {
    throw new Error(`Gagal membaca stasiun: ${stationError.message}`);
  }
  const stationIdByCode = new Map(stationRows.map((r) => [r.code, r.id as string]));

  // 2. Lines, upserted by (operator_id, code) -> route_id, scoped to the
  // operator the admin selected.
  await upsertInChunks(
    supabase,
    "lines",
    feed.routes.map((route) => ({
      operator_id: operatorId,
      code: route.routeId,
      name: route.longName ?? route.shortName ?? route.routeId,
      transport_mode: routeTypeToTransportMode(route.routeType),
      color:
        route.color && HEX_COLOR.test(route.color) ? `#${route.color}` : null,
      text_color:
        route.textColor && HEX_COLOR.test(route.textColor)
          ? `#${route.textColor}`
          : null,
    })),
    "operator_id,code"
  );
  const { data: lineRows, error: lineError } = await supabase
    .from("lines")
    .select("id, code")
    .eq("operator_id", operatorId)
    .in(
      "code",
      feed.routes.map((r) => r.routeId)
    );
  if (lineError) {
    throw new Error(`Gagal membaca jalur: ${lineError.message}`);
  }
  const lineIdByCode = new Map(lineRows.map((r) => [r.code, r.id as string]));

  // 3. Expand calendar.txt/calendar_dates.txt into concrete (trip,
  // service_date) rows for the requested window.
  const stopTimesByTripId = new Map<string, typeof feed.stopTimes>();
  for (const stopTime of feed.stopTimes) {
    const list = stopTimesByTripId.get(stopTime.tripId) ?? [];
    list.push(stopTime);
    stopTimesByTripId.set(stopTime.tripId, list);
  }

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
    const lineId = lineIdByCode.get(trip.routeId);
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

  if (tripInserts.length === 0) {
    return {
      stopCount: feed.stops.length,
      routeCount: feed.routes.length,
      tripCount: feed.trips.length,
      serviceDaysExpanded: days.length,
      tripInstancesImported: 0,
      stopTimeRowsImported: 0,
    };
  }

  // `trips_external_service_unique_idx` is a PARTIAL unique index, which a
  // plain `.upsert()` cannot target (PostgREST has no way to add the
  // index's `where external_trip_id is not null` predicate to the ON
  // CONFLICT clause) — confirmed by testing directly against Postgres.
  // `import_gtfs_trips` (see the matching migration) does the upsert with
  // the full conflict target server-side and hands back the id mapping in
  // the same round trip.
  const tripIdByKey = new Map<string, string>();
  for (let i = 0; i < tripInserts.length; i += 500) {
    const chunk = tripInserts.slice(i, i + 500);
    const { data: rpcRows, error: rpcError } = await supabase.rpc(
      "import_gtfs_trips",
      { p_trips: chunk }
    );
    if (rpcError) {
      throw new Error(`Gagal mengimpor trip: ${rpcError.message}`);
    }
    for (const row of rpcRows as {
      out_external_trip_id: string;
      out_service_date: string;
      out_id: string;
    }[]) {
      tripIdByKey.set(
        `${row.out_external_trip_id}::${row.out_service_date}`,
        row.out_id
      );
    }
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

  // Replace stop_times for exactly the trips just (re)imported, so
  // re-running an import corrects a previous run rather than duplicating.
  const importedTripIds = [...new Set(stopTimeInserts.map((s) => s.trip_id))];
  for (let i = 0; i < importedTripIds.length; i += 200) {
    const chunk = importedTripIds.slice(i, i + 200);
    const { error: deleteError } = await supabase
      .from("stop_times")
      .delete()
      .in("trip_id", chunk);
    if (deleteError) {
      throw new Error(`Gagal membersihkan jadwal lama: ${deleteError.message}`);
    }
  }
  await upsertInChunks(
    supabase,
    "stop_times",
    stopTimeInserts,
    "trip_id,stop_sequence"
  );

  return {
    stopCount: feed.stops.length,
    routeCount: feed.routes.length,
    tripCount: feed.trips.length,
    serviceDaysExpanded: days.length,
    tripInstancesImported: tripInserts.length,
    stopTimeRowsImported: stopTimeInserts.length,
  };
}

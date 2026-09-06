import { mapRows } from "./csv";
import type {
  GtfsStop,
  GtfsRoute,
  GtfsTrip,
  GtfsStopTime,
  GtfsCalendar,
  GtfsCalendarDate,
} from "./types";

function nullIfEmpty(value: string | undefined): string | null {
  return value && value.length > 0 ? value : null;
}

/** GTFS `HH:MM:SS` — hours may exceed 23 for a service day continuing past
 * midnight, so this returns raw seconds rather than wrapping to 24h. */
function parseGtfsTimeOfDay(value: string): number {
  const parts = value.split(":");
  if (parts.length !== 3) {
    throw new Error(`Format waktu GTFS tidak valid: ${value}`);
  }
  const [h, m, s] = parts.map((p) => Number(p));
  if (![h, m, s].every(Number.isFinite)) {
    throw new Error(`Format waktu GTFS tidak valid: ${value}`);
  }
  return h * 3600 + m * 60 + s;
}

/** `YYYYMMDD` -> `YYYY-MM-DD`, kept as a plain string (no `Date`/timezone
 * involved) so date-only comparisons never trip over local-time skew. */
function parseGtfsDate(value: string): string {
  if (value.length !== 8) {
    throw new Error(`Format tanggal GTFS tidak valid: ${value}`);
  }
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`;
}

export function parseStops(csvText: string): GtfsStop[] {
  return mapRows(csvText, ["stop_id", "stop_name", "stop_lat", "stop_lon"]).map(
    (row) => {
      const latStr = row.stop_lat.trim();
      const lonStr = row.stop_lon.trim();
      let latitude = latStr !== "" ? Number(latStr) : 0;
      let longitude = lonStr !== "" ? Number(lonStr) : 0;
      if (!Number.isFinite(latitude)) latitude = 0;
      if (!Number.isFinite(longitude)) longitude = 0;

      const wheelchairBoarding =
        row.wheelchair_boarding === "1" ? 1 : row.wheelchair_boarding === "2" ? 2 : 0;
      return {
        stopId: row.stop_id,
        name: row.stop_name,
        latitude,
        longitude,
        description: nullIfEmpty(row.stop_desc),
        wheelchairBoarding: wheelchairBoarding as 0 | 1 | 2,
      };
    }
  );
}

/** Parses the "Label: value | Label: value" convention some real feeds use
 * in `stop_desc` to carry platform/facility/accessibility notes (GTFS has
 * no dedicated columns for these). Splits only on each segment's *first*
 * colon, since values themselves can contain one (e.g.
 * "Aksesibilitas: Aksesibilitas jaringan: guiding block, ..."). Returns an
 * empty object for a missing/unstructured description rather than guessing
 * — `stations.facilities` defaults to `{}` for exactly this case. */
export function parseStationDescription(
  description: string | null
): Record<string, string> {
  if (!description) return {};
  const result: Record<string, string> = {};
  for (const segment of description.split("|")) {
    const colonIndex = segment.indexOf(":");
    if (colonIndex === -1) continue;
    const label = segment.slice(0, colonIndex).trim();
    const value = segment.slice(colonIndex + 1).trim();
    if (!label || !value) continue;
    const key = label
      .toLowerCase()
      .normalize("NFKD")
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "");
    if (key) result[key] = value;
  }
  return result;
}

export function parseRoutes(csvText: string): GtfsRoute[] {
  return mapRows(csvText, ["route_id"]).map((row) => ({
    routeId: row.route_id,
    shortName: nullIfEmpty(row.route_short_name),
    longName: nullIfEmpty(row.route_long_name),
    color: nullIfEmpty(row.route_color),
    textColor: nullIfEmpty(row.route_text_color),
    routeType:
      row.route_type && row.route_type.length > 0
        ? Number(row.route_type)
        : null,
  }));
}

export function parseTrips(csvText: string): GtfsTrip[] {
  return mapRows(csvText, ["trip_id", "route_id", "service_id"]).map(
    (row) => ({
      tripId: row.trip_id,
      routeId: row.route_id,
      serviceId: row.service_id,
      headsign: nullIfEmpty(row.trip_headsign),
      tripShortName: nullIfEmpty(row.trip_short_name),
    })
  );
}

export function parseStopTimes(csvText: string): GtfsStopTime[] {
  return mapRows(csvText, [
    "trip_id",
    "stop_id",
    "stop_sequence",
    "arrival_time",
    "departure_time",
  ]).map((row) => {
    const stopSequence = Number(row.stop_sequence);
    if (!Number.isFinite(stopSequence)) {
      throw new Error(`stop_sequence tidak valid untuk trip ${row.trip_id}.`);
    }
    return {
      tripId: row.trip_id,
      stopId: row.stop_id,
      stopSequence,
      arrivalSeconds: parseGtfsTimeOfDay(row.arrival_time),
      departureSeconds: parseGtfsTimeOfDay(row.departure_time),
    };
  });
}

export function parseCalendar(csvText: string): GtfsCalendar[] {
  return mapRows(csvText, [
    "service_id",
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
    "start_date",
    "end_date",
  ]).map((row) => ({
    serviceId: row.service_id,
    weekdays: [
      row.monday === "1",
      row.tuesday === "1",
      row.wednesday === "1",
      row.thursday === "1",
      row.friday === "1",
      row.saturday === "1",
      row.sunday === "1",
    ],
    startDate: parseGtfsDate(row.start_date),
    endDate: parseGtfsDate(row.end_date),
  }));
}

export function parseCalendarDates(csvText: string): GtfsCalendarDate[] {
  return mapRows(csvText, ["service_id", "date", "exception_type"]).map(
    (row) => ({
      serviceId: row.service_id,
      date: parseGtfsDate(row.date),
      exceptionType: row.exception_type === "1" ? 1 : 2,
    })
  );
}

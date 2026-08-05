import type { GtfsCalendar, GtfsCalendarDate } from "./types";

/** Maps a GTFS `route_type` code to this project's `lines.transport_mode`
 * enum. Falls back to `'other'` for anything not explicitly listed (cable
 * tram, aerial lift, funicular, etc. — real but rare enough not to need
 * their own bucket yet). */
export function routeTypeToTransportMode(routeType: number | null): string {
  switch (routeType) {
    case 0:
      return "lrt"; // Tram, streetcar, light rail
    case 1:
      return "metro"; // Subway, metro
    case 2:
      return "rail"; // Rail
    case 3:
      return "bus";
    case 4:
      return "other"; // Ferry
    case 11:
      return "bus"; // Trolleybus
    case 12:
      return "other"; // Monorail
    default:
      return "other";
  }
}

function toDateOnly(iso: string): Date {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

function toIso(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** Every date (as `YYYY-MM-DD`) from `startIso` for `days` days, inclusive. */
export function dateWindow(startIso: string, days: number): string[] {
  const start = toDateOnly(startIso);
  const result: string[] = [];
  for (let i = 0; i < days; i += 1) {
    const day = new Date(start);
    day.setUTCDate(day.getUTCDate() + i);
    result.push(toIso(day));
  }
  return result;
}

export class ServiceCalendar {
  private readonly weekly = new Map<string, GtfsCalendar>();
  private readonly exceptions = new Map<string, Map<string, 1 | 2>>();

  constructor(calendar: GtfsCalendar[], calendarDates: GtfsCalendarDate[]) {
    for (const entry of calendar) {
      this.weekly.set(entry.serviceId, entry);
    }
    for (const exception of calendarDates) {
      const byDate =
        this.exceptions.get(exception.serviceId) ?? new Map<string, 1 | 2>();
      byDate.set(exception.date, exception.exceptionType);
      this.exceptions.set(exception.serviceId, byDate);
    }
  }

  runsOn(serviceId: string, dateIso: string): boolean {
    const exceptionType = this.exceptions.get(serviceId)?.get(dateIso);
    if (exceptionType === 1) return true;
    if (exceptionType === 2) return false;

    const entry = this.weekly.get(serviceId);
    if (!entry) return false;
    if (dateIso < entry.startDate || dateIso > entry.endDate) return false;

    // Date.UTC-based weekday: getUTCDay() is 0=Sunday..6=Saturday; convert
    // to this project's 0=Monday..6=Sunday convention.
    const weekday = toDateOnly(dateIso).getUTCDay();
    const mondayIndexed = (weekday + 6) % 7;
    return entry.weekdays[mondayIndexed];
  }
}

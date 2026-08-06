export type GtfsStop = {
  stopId: string;
  name: string;
  latitude: number;
  longitude: number;
  /** Raw `stop_desc` text, if present — see `parseStationDescription` in
   * `parser.ts` for the "Label: value | Label: value" convention some real
   * feeds (e.g. the community KRL conversion) use to carry platform/
   * facility/accessibility notes that GTFS has no dedicated columns for. */
  description: string | null;
  /** GTFS `wheelchair_boarding`: 0 = no info, 1 = accessible, 2 = not. */
  wheelchairBoarding: 0 | 1 | 2;
};

export type GtfsRoute = {
  routeId: string;
  shortName: string | null;
  longName: string | null;
  color: string | null;
  textColor: string | null;
  routeType: number | null;
};

export type GtfsTrip = {
  tripId: string;
  routeId: string;
  serviceId: string;
  headsign: string | null;
  tripShortName: string | null;
};

/** Seconds since midnight of the service day — may exceed 86400 for a trip
 * that runs past midnight, deliberately not wrapped to a 24h clock. */
export type GtfsStopTime = {
  tripId: string;
  stopId: string;
  stopSequence: number;
  arrivalSeconds: number;
  departureSeconds: number;
};

export type GtfsCalendar = {
  serviceId: string;
  /** Index 0 = Monday .. 6 = Sunday. */
  weekdays: boolean[];
  startDate: string; // YYYY-MM-DD
  endDate: string; // YYYY-MM-DD
};

export type GtfsCalendarDate = {
  serviceId: string;
  date: string; // YYYY-MM-DD
  exceptionType: 1 | 2; // 1 = added, 2 = removed
};

export type GtfsFeed = {
  stops: GtfsStop[];
  routes: GtfsRoute[];
  trips: GtfsTrip[];
  stopTimes: GtfsStopTime[];
  calendar: GtfsCalendar[];
  calendarDates: GtfsCalendarDate[];
};

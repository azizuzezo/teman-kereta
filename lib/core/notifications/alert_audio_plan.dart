/// Which recorded voice line (a `res/raw` name, see
/// `android/app/src/main/res/raw`) belongs to which trip alert, whether the
/// bell follows it, and which notification channel carries it.
///
/// Pure, and mirrored by `TripNotifier.kt` on the native side: the two must
/// agree on the names, because an alert decided natively and one decided in
/// Dart have to sound and group identically.
library;

/// Generic channel for alerts with no recorded voice line (a stop alert with
/// more than three stations left). It keeps the system notification sound
/// and is read aloud by the text-to-speech fallback.
const genericAlertChannelId = 'trip_alerts';

const arrivalVoice = 'arrive_station';
const transferReminderVoice = 'transit_reminder';
const missedDestinationVoice = 'terlewat';

/// Voice line for "[remainingStops] stasiun lagi" before the destination;
/// the destination itself (0 left) uses the arrival line.
String? stopAlertVoice(int remainingStops) {
  if (remainingStops == 0) return arrivalVoice;
  if (remainingStops >= 1 && remainingStops <= 3) {
    return 'remaining_station_$remainingStops';
  }
  return null;
}

/// Voice line for "[remainingStops] stasiun lagi menuju transit".
String? transferApproachingVoice(int remainingStops) {
  if (remainingStops >= 1 && remainingStops <= 3) {
    return 'remaining_transit_$remainingStops';
  }
  return null;
}

/// The bell (`assets/alarm.mp3`) follows the voice line only for the last
/// station before a stop or transfer.
bool bellFollowsVoice(int remainingStops) => remainingStops == 1;

/// Rail distance left, in km, at which an intercity ride is announced, largest
/// first. Intercity stops are tens of minutes apart, so "3, 2, 1 stations
/// before" says nothing there; and with no timetable the distance along the
/// rails is the one thing that is known for sure.
const intercityReminderKm = <int>[30, 15, 10];

/// Recorded voice lines for "[km] kilometer lagi" that are bundled in
/// `res/raw` as `eta_km_<km>`. A distance goes here only together with its file
/// (and its line in `keep.xml`): an alert whose clip is missing would be
/// silent, so without one the text-to-speech reads it instead.
const _bundledIntercityKmClips = <int>{30, 15, 10};

/// Recorded voice line for "[km] kilometer lagi", or null when there is no
/// clip for that distance and the text-to-speech reads it instead.
String? intercityKmVoice(int km) =>
    _bundledIntercityKmClips.contains(km) ? 'eta_km_$km' : null;

/// The bell follows the last reminder only: the one that means "get ready to
/// leave the seat".
bool bellFollowsIntercityVoice(int km) => km == intercityReminderKm.last;

/// Channel id for an alert whose voice line is [voice].
///
/// The recorded voice is played by the app itself (so it can be sequenced
/// with the bell and sent to a headset), which is why these channels are
/// silent. They are new ids: an Android channel's sound cannot be changed
/// after it is created, and the old `trip_alert_*` channels carried the wav
/// as their own sound.
String alertChannelId(String? voice) =>
    voice == null ? genericAlertChannelId : 'tk_alert_$voice';

/// Channels that carried a voice line as their own sound before the app
/// started playing it itself. Deleted on startup so they do not linger in
/// the system settings next to their silent replacements.
const retiredAlertChannelIds = <String>[
  'trip_alert_arrive_station',
  'trip_alert_remaining_station_1',
  'trip_alert_remaining_station_2',
  'trip_alert_remaining_station_3',
  'trip_alert_remaining_transit_1',
  'trip_alert_remaining_transit_2',
  'trip_alert_remaining_transit_3',
  'trip_alert_transit_reminder',
  'trip_alert_terlewat',
  'trip_alert_alert_terlewat',
];

package id.temankereta.teman_kereta

import android.content.Context
import android.content.SharedPreferences
import java.text.DateFormat
import java.util.Date
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * Small, process-safe native state store shared by Flutter, widgets, receivers, and the
 * foreground service. Location data never leaves this private SharedPreferences file.
 */
internal object NativeStateStore {
    const val PREFERENCES_NAME = "teman_kereta_native_state"

    const val ACTIVE = "active_trip.is_active"
    const val ACTIVE_TRIP_ID = "active_trip.trip_id"
    const val ACTIVE_LINE = "active_trip.line_name"
    const val ACTIVE_DESTINATION = "active_trip.destination_name"
    const val ACTIVE_CURRENT_STATION = "active_trip.current_station"
    const val ACTIVE_NEXT_STATION = "active_trip.next_station"
    const val ACTIVE_REMAINING = "active_trip.remaining_stations"
    const val ACTIVE_ETA = "active_trip.eta"
    const val ACTIVE_PROGRESS = "active_trip.progress"
    const val ACTIVE_IS_DEMO = "active_trip.is_demo"
    const val ACTIVE_UPDATED_AT = "active_trip.updated_at_epoch_ms"
    const val ACTIVE_LOCATION_LATITUDE = "active_trip.location.latitude"
    const val ACTIVE_LOCATION_LONGITUDE = "active_trip.location.longitude"
    const val ACTIVE_LOCATION_ACCURACY = "active_trip.location.accuracy_meters"
    const val ACTIVE_LOCATION_SPEED = "active_trip.location.speed_mps"
    const val ACTIVE_LOCATION_BEARING = "active_trip.location.bearing_degrees"
    const val ACTIVE_LOCATION_AT = "active_trip.location.at_epoch_ms"
    const val ACTIVE_LOCATION_STATUS = "active_trip.location.status"

    // State-machine fields the native `TripProgressEngine` owns once a trip
    // starts — this is the data continuous-GPS progression needs that the
    // old geofence-only design never had to persist natively (station
    // coordinates/order, transfer instructions, live alert settings), since
    // advancing/notifying now happens here instead of only in Dart.
    const val ACTIVE_SESSION_ID = "active_trip.session_id"
    // When the rider started this trip. Needed natively (not just in Dart)
    // so the arrival notification can carry a real travel time even when the
    // Flutter engine is gone by the time the destination is reached.
    const val ACTIVE_STARTED_AT = "active_trip.started_at_epoch_ms"
    const val ACTIVE_STATE = "active_trip.state"
    const val ACTIVE_CURRENT_STATION_ID = "active_trip.current_station_id"
    const val ACTIVE_NEXT_STATION_ID = "active_trip.next_station_id"
    const val ACTIVE_DESTINATION_STATION_ID = "active_trip.destination_station_id"
    const val ACTIVE_CURRENT_STATION_INDEX = "active_trip.current_station_index"
    const val ACTIVE_DISTANCE_METERS = "active_trip.distance_meters"
    const val ACTIVE_SPEED_KMH = "active_trip.speed_kmh"
    const val ACTIVE_LOW_BATTERY_MODE = "active_trip.low_battery_mode"
    const val ACTIVE_STOP_ALERT_THRESHOLD = "active_trip.stop_alert_threshold"
    const val ACTIVE_VIBRATION_ENABLED = "active_trip.vibration_enabled"
    const val ACTIVE_SOUND_ENABLED = "active_trip.sound_enabled"
    const val ACTIVE_ROUTE_STATIONS_JSON = "active_trip.route_stations_json"
    const val ACTIVE_TRANSFER_BOUNDARIES_JSON = "active_trip.transfer_boundaries_json"
    const val ACTIVE_MIN_DESTINATION_DISTANCE_METERS = "active_trip.min_destination_distance_meters"
    const val ACTIVE_PENDING_COMPLETION_LOG = "active_trip.pending_completion_log"
    const val ACTIVE_PENDING_MISSED_LOG = "active_trip.pending_missed_destination_log"

    // A recovered signal gap: GPS went quiet mid-trip and the fix that
    // eventually came back put the rider somewhere meaningfully different.
    // Recorded by `ActiveTripLocationService`, drained by Dart on the next
    // foreground resume so it can ask "masih di kereta?" — the trip itself
    // stays active either way, this is only what the prompt is built from.
    const val ACTIVE_GAP_PENDING = "active_trip.location_gap.pending"
    const val ACTIVE_GAP_FROM_LATITUDE = "active_trip.location_gap.from_latitude"
    const val ACTIVE_GAP_FROM_LONGITUDE = "active_trip.location_gap.from_longitude"
    const val ACTIVE_GAP_FROM_AT = "active_trip.location_gap.from_at_epoch_ms"
    const val ACTIVE_GAP_TO_LATITUDE = "active_trip.location_gap.to_latitude"
    const val ACTIVE_GAP_TO_LONGITUDE = "active_trip.location_gap.to_longitude"
    const val ACTIVE_GAP_TO_AT = "active_trip.location_gap.to_at_epoch_ms"
    const val ACTIVE_GAP_DISTANCE_METERS = "active_trip.location_gap.distance_meters"

    const val NEXT_HAS_DATA = "next_departure.has_data"
    const val NEXT_STATION = "next_departure.station"
    const val NEXT_TIME = "next_departure.departure_time"
    const val NEXT_DESTINATION = "next_departure.destination"
    const val NEXT_STATUS = "next_departure.status"
    const val NEXT_IS_DEMO = "next_departure.is_demo"
    const val NEXT_UPDATED_AT = "next_departure.updated_at_epoch_ms"

    const val ACTIVITY_LAST_TYPE = "activity_recognition.last_event.type"
    const val ACTIVITY_LAST_CONFIDENCE = "activity_recognition.last_event.confidence"
    const val ACTIVITY_LAST_AT = "activity_recognition.last_event.at_epoch_ms"

    const val DAILY_ROUTE_HAS_DATA = "daily_route.has_data"
    const val DAILY_ROUTE_LABEL = "daily_route.label"
    const val DAILY_ROUTE_LINE_STATUS = "daily_route.line_status"
    const val DAILY_ROUTE_IS_DEMO = "daily_route.is_demo"
    const val DAILY_ROUTE_UPDATED_AT = "daily_route.updated_at_epoch_ms"
    val DAILY_ROUTE_DEPARTURE_TIME = listOf(
        "daily_route.departure_1.time",
        "daily_route.departure_2.time",
        "daily_route.departure_3.time",
    )
    val DAILY_ROUTE_DEPARTURE_DESTINATION = listOf(
        "daily_route.departure_1.destination",
        "daily_route.departure_2.destination",
        "daily_route.departure_3.destination",
    )

    const val SERVICE_STATUS_HAS_DATA = "service_status.has_data"
    const val SERVICE_STATUS_IS_DEMO = "service_status.is_demo"
    const val SERVICE_STATUS_UPDATED_AT = "service_status.updated_at_epoch_ms"
    val SERVICE_STATUS_LINE_NAME = listOf(
        "service_status.line_1.name",
        "service_status.line_2.name",
        "service_status.line_3.name",
        "service_status.line_4.name",
    )
    val SERVICE_STATUS_LINE_STATUS = listOf(
        "service_status.line_1.status",
        "service_status.line_2.status",
        "service_status.line_3.status",
        "service_status.line_4.status",
    )

    private val activeKeys = listOf(
        ACTIVE,
        ACTIVE_TRIP_ID,
        ACTIVE_LINE,
        ACTIVE_DESTINATION,
        ACTIVE_CURRENT_STATION,
        ACTIVE_NEXT_STATION,
        ACTIVE_REMAINING,
        ACTIVE_ETA,
        ACTIVE_PROGRESS,
        ACTIVE_IS_DEMO,
        ACTIVE_UPDATED_AT,
        ACTIVE_LOCATION_LATITUDE,
        ACTIVE_LOCATION_LONGITUDE,
        ACTIVE_LOCATION_ACCURACY,
        ACTIVE_LOCATION_SPEED,
        ACTIVE_LOCATION_BEARING,
        ACTIVE_LOCATION_AT,
        ACTIVE_LOCATION_STATUS,
        ACTIVE_SESSION_ID,
        ACTIVE_STARTED_AT,
        ACTIVE_STATE,
        ACTIVE_CURRENT_STATION_ID,
        ACTIVE_NEXT_STATION_ID,
        ACTIVE_DESTINATION_STATION_ID,
        ACTIVE_CURRENT_STATION_INDEX,
        ACTIVE_DISTANCE_METERS,
        ACTIVE_SPEED_KMH,
        ACTIVE_LOW_BATTERY_MODE,
        ACTIVE_STOP_ALERT_THRESHOLD,
        ACTIVE_VIBRATION_ENABLED,
        ACTIVE_SOUND_ENABLED,
        ACTIVE_ROUTE_STATIONS_JSON,
        ACTIVE_TRANSFER_BOUNDARIES_JSON,
        ACTIVE_MIN_DESTINATION_DISTANCE_METERS,
        ACTIVE_PENDING_COMPLETION_LOG,
        ACTIVE_PENDING_MISSED_LOG,
        ACTIVE_GAP_PENDING,
        ACTIVE_GAP_FROM_LATITUDE,
        ACTIVE_GAP_FROM_LONGITUDE,
        ACTIVE_GAP_FROM_AT,
        ACTIVE_GAP_TO_LATITUDE,
        ACTIVE_GAP_TO_LONGITUDE,
        ACTIVE_GAP_TO_AT,
        ACTIVE_GAP_DISTANCE_METERS,
    )

    fun preferences(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun startActiveTrip(context: Context, data: Map<*, *>) {
        val editor = preferences(context).edit()
        activeKeys.forEach(editor::remove)
        editor.putBoolean(ACTIVE, true)
        editor.putString(ACTIVE_TRIP_ID, data.string("tripId", "trip_id")!!.trim())
        editor.putString(ACTIVE_LINE, data.string("lineName", "line_name", "line", "lineId").orEmpty().clean())
        editor.putString(
            ACTIVE_DESTINATION,
            data.string(
                "destinationName",
                "destination_name",
                "destination",
                "destinationStationId",
            ).orEmpty().clean(),
        )
        editor.putString(
            ACTIVE_CURRENT_STATION,
            data.string("currentStation", "current_station", "currentStationId").orEmpty().clean(),
        )
        editor.putString(
            ACTIVE_NEXT_STATION,
            data.string("nextStation", "next_station", "nextStationId").orEmpty().clean(),
        )
        editor.putInt(
            ACTIVE_REMAINING,
            data.int("remainingStations", "remaining_stations", "remainingStops")?.coerceAtLeast(0) ?: 0,
        )
        editor.putString(ACTIVE_ETA, data.etaLabel().clean())
        editor.putFloat(ACTIVE_PROGRESS, data.progressValue().toFloat())
        editor.putBoolean(ACTIVE_IS_DEMO, data.isDemo())
        editor.putLong(
            ACTIVE_UPDATED_AT,
            data.long("updatedAtEpochMs", "updated_at_epoch_ms") ?: System.currentTimeMillis(),
        )
        editor.putString(ACTIVE_LOCATION_STATUS, "starting")
        applyTripStateFields(editor, data)
        editor.putString(ACTIVE_SESSION_ID, data.string("sessionId", "session_id").orEmpty())
        editor.putLong(
            ACTIVE_STARTED_AT,
            data.long("startedAtEpochMs", "started_at_epoch_ms") ?: System.currentTimeMillis(),
        )
        editor.putString(ACTIVE_STATE, data.string("state").orEmpty().ifEmpty { "onBoard" })
        editor.putInt(
            ACTIVE_CURRENT_STATION_INDEX,
            data.int("currentStationIndex", "current_station_index") ?: 0,
        )
        editor.putLong(ACTIVE_DISTANCE_METERS, java.lang.Double.doubleToRawLongBits(0.0))
        editor.remove(ACTIVE_SPEED_KMH)
        editor.remove(ACTIVE_MIN_DESTINATION_DISTANCE_METERS)
        editor.putBoolean(ACTIVE_PENDING_COMPLETION_LOG, false)
        editor.putBoolean(ACTIVE_PENDING_MISSED_LOG, false)
        editor.apply()
    }

    /**
     * Merges a Dart-side trip update into native state.
     *
     * Progress fields are guarded: **native owns trip progress, Dart does
     * not.** `TripProgressEngine` keeps advancing the trip while the
     * Flutter engine is dead (app swiped away, process killed), so the
     * session Dart restores from SharedPreferences on relaunch can easily
     * be several stations behind — and `ActiveTripController.build()`
     * pushes that restored session straight back here before it has read
     * native's newer state. Applying it verbatim rewound the trip to where
     * it was when the app died, which is one of the ways progress appeared
     * to "get stuck": every restart undid the tracking done while away.
     *
     * So an update carrying an older `currentStationIndex` than the one
     * already stored keeps its route/settings changes and drops its
     * position claims. Route data, alert preferences and low-battery mode
     * are never progress and always apply.
     */
    fun updateActiveTrip(context: Context, data: Map<*, *>) {
        val prefs = preferences(context)
        val incomingIndex = data.intIfPresent("currentStationIndex", "current_station_index")
        val isStaleProgress = incomingIndex != null &&
            prefs.getBoolean(ACTIVE, false) &&
            incomingIndex < prefs.getInt(ACTIVE_CURRENT_STATION_INDEX, 0)
        val editor = prefs.edit()
        data.stringIfPresent("lineName", "line_name", "line", "lineId")?.let {
            editor.putString(ACTIVE_LINE, it.clean())
        }
        data.stringIfPresent(
            "destinationName",
            "destination_name",
            "destination",
            "destinationStationId",
        )?.let {
            editor.putString(ACTIVE_DESTINATION, it.clean())
        }
        if (!isStaleProgress) {
            data.stringIfPresent("currentStation", "current_station", "currentStationId")?.let {
                editor.putString(ACTIVE_CURRENT_STATION, it.clean())
            }
            data.stringIfPresent("nextStation", "next_station", "nextStationId")?.let {
                editor.putString(ACTIVE_NEXT_STATION, it.clean())
            }
            data.intIfPresent("remainingStations", "remaining_stations", "remainingStops")?.let {
                editor.putInt(ACTIVE_REMAINING, it.coerceAtLeast(0))
            }
        }
        if (data.hasAny("eta", "estimatedArrival", "etaEpochMillis", "eta_epoch_millis")) {
            editor.putString(ACTIVE_ETA, data.etaLabel().clean())
        }
        if (!isStaleProgress && data.hasAny("progress", "stationIds", "station_ids")) {
            editor.putFloat(ACTIVE_PROGRESS, data.progressValue().toFloat())
        }
        if (data.hasAny("isDemo", "is_demo", "dataSource", "data_source")) {
            editor.putBoolean(ACTIVE_IS_DEMO, data.isDemo())
        }
        editor.putLong(
            ACTIVE_UPDATED_AT,
            data.long("updatedAtEpochMs", "updated_at_epoch_ms") ?: System.currentTimeMillis(),
        )
        applyTripStateFields(editor, data, applyPositionIds = !isStaleProgress)
        if (!isStaleProgress) {
            data.stringIfPresent("state")?.let { editor.putString(ACTIVE_STATE, it) }
            if (incomingIndex != null) {
                editor.putInt(ACTIVE_CURRENT_STATION_INDEX, incomingIndex)
            }
            // The odometer only ever grows, for the same reason: a restored
            // session's distance can lag what native has already measured.
            data.doubleIfPresent("distanceMeters", "distance_meters")?.let {
                val stored = distanceMeters(context)
                editor.putLong(
                    ACTIVE_DISTANCE_METERS,
                    java.lang.Double.doubleToRawLongBits(maxOf(it, stored)),
                )
            }
        }
        editor.apply()
    }

    /// Fields carried by both `startActiveTrip` and `updateActiveTrip` that
    /// the native `TripProgressEngine` needs to decide/announce progress on
    /// its own — station coordinates/order, transfer instructions, and the
    /// user's live alert preferences (Dart no longer has to be alive for a
    /// setting change to reach native; see [updateSettings]).
    private fun applyTripStateFields(
        editor: SharedPreferences.Editor,
        data: Map<*, *>,
        applyPositionIds: Boolean = true,
    ) {
        data.stringIfPresent("destinationStationId", "destination_station_id")?.let {
            editor.putString(ACTIVE_DESTINATION_STATION_ID, it)
        }
        if (applyPositionIds) {
            data.stringIfPresent("currentStationId", "current_station_id")?.let {
                editor.putString(ACTIVE_CURRENT_STATION_ID, it)
            }
            data.stringIfPresent("nextStationId", "next_station_id")?.let {
                editor.putString(ACTIVE_NEXT_STATION_ID, it)
            }
        }
        data.boolean("lowBatteryMode", "low_battery_mode")?.let {
            editor.putBoolean(ACTIVE_LOW_BATTERY_MODE, it)
        }
        data.intIfPresent("stopAlertThreshold", "stop_alert_threshold")?.let {
            editor.putInt(ACTIVE_STOP_ALERT_THRESHOLD, it)
        }
        data.boolean("vibrationEnabled", "vibration_enabled")?.let {
            editor.putBoolean(ACTIVE_VIBRATION_ENABLED, it)
        }
        data.boolean("soundEnabled", "sound_enabled")?.let {
            editor.putBoolean(ACTIVE_SOUND_ENABLED, it)
        }
        (data.value("stations") as? List<*>)?.let { stations ->
            editor.putString(ACTIVE_ROUTE_STATIONS_JSON, encodeRouteStations(stations))
        }
        (data.value("transferBoundaries", "transfer_boundaries") as? List<*>)?.let { boundaries ->
            editor.putString(ACTIVE_TRANSFER_BOUNDARIES_JSON, encodeTransferBoundaries(boundaries))
        }
    }

    /// Pushes just the live alert-preference fields, without touching route
    /// or position state — used when the user changes a notification
    /// setting mid-trip (see `updateSettings` on the Dart bridge).
    fun updateSettings(context: Context, data: Map<*, *>) {
        val editor = preferences(context).edit()
        data.intIfPresent("stopAlertThreshold", "stop_alert_threshold")?.let {
            editor.putInt(ACTIVE_STOP_ALERT_THRESHOLD, it)
        }
        data.boolean("vibrationEnabled", "vibration_enabled")?.let {
            editor.putBoolean(ACTIVE_VIBRATION_ENABLED, it)
        }
        data.boolean("soundEnabled", "sound_enabled")?.let {
            editor.putBoolean(ACTIVE_SOUND_ENABLED, it)
        }
        editor.apply()
    }

    fun clearActiveTrip(context: Context) {
        val editor = preferences(context).edit()
        activeKeys.forEach(editor::remove)
        editor.apply()
    }

    fun putNextDeparture(context: Context, data: Map<*, *>) {
        preferences(context).edit()
            .putBoolean(NEXT_HAS_DATA, true)
            .putString(NEXT_STATION, data.string("station", "stationName", "station_name").orEmpty().clean())
            .putString(NEXT_TIME, data.string("departureTime", "departure_time", "time").orEmpty().clean())
            .putString(NEXT_DESTINATION, data.string("destination", "destinationName").orEmpty().clean())
            .putString(NEXT_STATUS, data.string("status", "serviceStatus").orEmpty().clean())
            .putBoolean(NEXT_IS_DEMO, data.isDemo())
            .putLong(
                NEXT_UPDATED_AT,
                data.long("updatedAtEpochMs", "updated_at_epoch_ms") ?: System.currentTimeMillis(),
            )
            .apply()
    }

    fun activeTripSnapshot(context: Context): Map<String, Any?> {
        val prefs = preferences(context)
        return mapOf(
            "isActive" to prefs.getBoolean(ACTIVE, false),
            "tripId" to prefs.getString(ACTIVE_TRIP_ID, null),
            "lineName" to prefs.getString(ACTIVE_LINE, null),
            "destinationName" to prefs.getString(ACTIVE_DESTINATION, null),
            "currentStation" to prefs.getString(ACTIVE_CURRENT_STATION, null),
            "nextStation" to prefs.getString(ACTIVE_NEXT_STATION, null),
            "remainingStations" to prefs.getInt(ACTIVE_REMAINING, 0),
            "eta" to prefs.getString(ACTIVE_ETA, null),
            "progress" to prefs.getFloat(ACTIVE_PROGRESS, 0f).toDouble(),
            "isDemo" to prefs.getBoolean(ACTIVE_IS_DEMO, false),
            "updatedAtEpochMs" to prefs.getLong(ACTIVE_UPDATED_AT, 0L),
            "locationStatus" to prefs.getString(ACTIVE_LOCATION_STATUS, "idle"),
            "latitude" to prefs.optionalDouble(ACTIVE_LOCATION_LATITUDE),
            "longitude" to prefs.optionalDouble(ACTIVE_LOCATION_LONGITUDE),
            "accuracyMeters" to prefs.optionalFloat(ACTIVE_LOCATION_ACCURACY)?.toDouble(),
            "speedMetersPerSecond" to prefs.optionalFloat(ACTIVE_LOCATION_SPEED)?.toDouble(),
            "locationAtEpochMs" to prefs.optionalLong(ACTIVE_LOCATION_AT),
        )
    }

    data class RouteStation(
        val id: String,
        val name: String,
        val latitude: Double,
        val longitude: Double,
    )

    data class TransferBoundaryDetail(
        val index: Int,
        val instruction: String?,
    )

    fun encodeRouteStations(stations: List<*>): String {
        val array = JSONArray()
        stations.forEach { raw ->
            val station = raw as? Map<*, *> ?: return@forEach
            val id = station.string("id", "stationId") ?: return@forEach
            array.put(
                JSONObject()
                    .put("id", id)
                    .put("name", station.string("name").orEmpty().ifEmpty { id })
                    .put("latitude", station.double("latitude", "lat") ?: 0.0)
                    .put("longitude", station.double("longitude", "lng", "lon") ?: 0.0),
            )
        }
        return array.toString()
    }

    fun decodeRouteStations(raw: String?): List<RouteStation> {
        if (raw.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { index ->
                val obj = array.getJSONObject(index)
                RouteStation(
                    id = obj.getString("id"),
                    name = obj.optString("name", obj.getString("id")),
                    latitude = obj.getDouble("latitude"),
                    longitude = obj.getDouble("longitude"),
                )
            }
        } catch (error: JSONException) {
            emptyList()
        }
    }

    fun encodeTransferBoundaries(boundaries: List<*>): String {
        val array = JSONArray()
        boundaries.forEach { raw ->
            val boundary = raw as? Map<*, *> ?: return@forEach
            val index = boundary.int("index") ?: return@forEach
            array.put(
                JSONObject()
                    .put("index", index)
                    .put("instruction", boundary.string("instruction") ?: JSONObject.NULL),
            )
        }
        return array.toString()
    }

    fun decodeTransferBoundaries(raw: String?): List<TransferBoundaryDetail> {
        if (raw.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { index ->
                val obj = array.getJSONObject(index)
                TransferBoundaryDetail(
                    index = obj.getInt("index"),
                    instruction = if (obj.isNull("instruction")) null else obj.optString("instruction"),
                )
            }
        } catch (error: JSONException) {
            emptyList()
        }
    }

    fun routeStations(context: Context): List<RouteStation> =
        decodeRouteStations(preferences(context).getString(ACTIVE_ROUTE_STATIONS_JSON, null))

    fun transferBoundaries(context: Context): List<TransferBoundaryDetail> =
        decodeTransferBoundaries(preferences(context).getString(ACTIVE_TRANSFER_BOUNDARIES_JSON, null))

    fun startedAtEpochMs(context: Context): Long =
        preferences(context).getLong(ACTIVE_STARTED_AT, 0L)

    fun currentStationIndex(context: Context): Int =
        preferences(context).getInt(ACTIVE_CURRENT_STATION_INDEX, 0)

    fun tripState(context: Context): String =
        preferences(context).getString(ACTIVE_STATE, "onBoard") ?: "onBoard"

    fun destinationStationId(context: Context): String? =
        preferences(context).getString(ACTIVE_DESTINATION_STATION_ID, null)

    fun lowBatteryMode(context: Context): Boolean =
        preferences(context).getBoolean(ACTIVE_LOW_BATTERY_MODE, false)

    fun stopAlertThreshold(context: Context): Int =
        preferences(context).getInt(ACTIVE_STOP_ALERT_THRESHOLD, 3)

    fun vibrationEnabled(context: Context): Boolean =
        preferences(context).getBoolean(ACTIVE_VIBRATION_ENABLED, true)

    fun soundEnabled(context: Context): Boolean =
        preferences(context).getBoolean(ACTIVE_SOUND_ENABLED, true)

    fun isDemo(context: Context): Boolean =
        preferences(context).getBoolean(ACTIVE_IS_DEMO, false)

    fun distanceMeters(context: Context): Double {
        val prefs = preferences(context)
        return if (prefs.contains(ACTIVE_DISTANCE_METERS)) {
            java.lang.Double.longBitsToDouble(prefs.getLong(ACTIVE_DISTANCE_METERS, 0L))
        } else {
            0.0
        }
    }

    fun minDestinationDistanceMeters(context: Context): Double? {
        val prefs = preferences(context)
        return if (prefs.contains(ACTIVE_MIN_DESTINATION_DISTANCE_METERS)) {
            java.lang.Double.longBitsToDouble(prefs.getLong(ACTIVE_MIN_DESTINATION_DISTANCE_METERS, 0L))
        } else {
            null
        }
    }

    /// Records that GPS went quiet for [gapMillis] and came back somewhere
    /// [distanceMeters] away. Only ever one pending gap at a time — a
    /// second gap before Dart has drained the first overwrites it, since
    /// the prompt only ever asks about "where you are now vs. where we last
    /// saw you", and the newest pair is the only one that answers that.
    fun recordLocationGap(
        context: Context,
        fromLatitude: Double,
        fromLongitude: Double,
        fromAtEpochMs: Long,
        toLatitude: Double,
        toLongitude: Double,
        toAtEpochMs: Long,
        distanceMeters: Double,
    ) {
        preferences(context).edit()
            .putBoolean(ACTIVE_GAP_PENDING, true)
            .putLong(ACTIVE_GAP_FROM_LATITUDE, java.lang.Double.doubleToRawLongBits(fromLatitude))
            .putLong(ACTIVE_GAP_FROM_LONGITUDE, java.lang.Double.doubleToRawLongBits(fromLongitude))
            .putLong(ACTIVE_GAP_FROM_AT, fromAtEpochMs)
            .putLong(ACTIVE_GAP_TO_LATITUDE, java.lang.Double.doubleToRawLongBits(toLatitude))
            .putLong(ACTIVE_GAP_TO_LONGITUDE, java.lang.Double.doubleToRawLongBits(toLongitude))
            .putLong(ACTIVE_GAP_TO_AT, toAtEpochMs)
            .putLong(ACTIVE_GAP_DISTANCE_METERS, java.lang.Double.doubleToRawLongBits(distanceMeters))
            .apply()
    }

    /// Clears the pending gap once the rider has answered (or dismissed)
    /// the "masih di kereta?" prompt. Dismissing counts as clearing: the
    /// prompt is a courtesy, never a gate on the trip staying active.
    fun clearLocationGap(context: Context) {
        preferences(context).edit()
            .putBoolean(ACTIVE_GAP_PENDING, false)
            .apply()
    }

    private fun locationGap(context: Context): Map<String, Any?>? {
        val prefs = preferences(context)
        if (!prefs.getBoolean(ACTIVE_GAP_PENDING, false)) return null
        val fromAt = prefs.optionalLong(ACTIVE_GAP_FROM_AT) ?: return null
        val toAt = prefs.optionalLong(ACTIVE_GAP_TO_AT) ?: return null
        return mapOf(
            "fromLatitude" to prefs.optionalDouble(ACTIVE_GAP_FROM_LATITUDE),
            "fromLongitude" to prefs.optionalDouble(ACTIVE_GAP_FROM_LONGITUDE),
            "fromAtEpochMs" to fromAt,
            "toLatitude" to prefs.optionalDouble(ACTIVE_GAP_TO_LATITUDE),
            "toLongitude" to prefs.optionalDouble(ACTIVE_GAP_TO_LONGITUDE),
            "toAtEpochMs" to toAt,
            "distanceMeters" to prefs.optionalDouble(ACTIVE_GAP_DISTANCE_METERS),
            "gapMillis" to (toAt - fromAt),
        )
    }

    /// Applied by `TripProgressEngine` after every accepted GPS fix — the
    /// continuous odometer/speed readout, plus (when it decided to advance)
    /// the new station index/state and whichever notification-relevant
    /// fields changed. A single write so a fix that both moves the odometer
    /// and advances a stop only touches SharedPreferences once.
    fun applyProgressUpdate(
        context: Context,
        distanceMeters: Double,
        speedKmh: Float?,
        currentStationIndex: Int? = null,
        state: String? = null,
        currentStationId: String? = null,
        currentStationName: String? = null,
        nextStationId: String? = null,
        nextStationName: String? = null,
        remainingStations: Int? = null,
        minDestinationDistanceMeters: Double? = null,
        pendingCompletionLog: Boolean? = null,
        pendingMissedLog: Boolean? = null,
    ) {
        val editor = preferences(context).edit()
        editor.putLong(ACTIVE_DISTANCE_METERS, java.lang.Double.doubleToRawLongBits(distanceMeters))
        if (speedKmh != null) editor.putFloat(ACTIVE_SPEED_KMH, speedKmh)
        if (currentStationIndex != null) {
            editor.putInt(ACTIVE_CURRENT_STATION_INDEX, currentStationIndex)
            // Dart reads this back as the moment the trip reached this
            // station. Without it, a trip that arrived while the app was
            // closed would be timed from when the app was next opened.
            editor.putLong(ACTIVE_UPDATED_AT, System.currentTimeMillis())
        }
        if (state != null) editor.putString(ACTIVE_STATE, state)
        // The *_STATION keys hold display names (foreground notification,
        // home-screen widget); the *_STATION_ID keys hold the raw ids Dart
        // reconciles against. Writing an id into a name key is what used to
        // make the ongoing notification read "Menuju CTA" instead of
        // "Menuju Citayam" after native advanced a stop on its own.
        if (currentStationId != null) editor.putString(ACTIVE_CURRENT_STATION_ID, currentStationId)
        if (nextStationId != null) editor.putString(ACTIVE_NEXT_STATION_ID, nextStationId)
        if (currentStationName != null) editor.putString(ACTIVE_CURRENT_STATION, currentStationName.clean())
        if (nextStationName != null) editor.putString(ACTIVE_NEXT_STATION, nextStationName.clean())
        if (nextStationId == null && nextStationName == null && remainingStations == 0) {
            editor.putString(ACTIVE_NEXT_STATION, "")
        }
        if (remainingStations != null) editor.putInt(ACTIVE_REMAINING, remainingStations.coerceAtLeast(0))
        if (minDestinationDistanceMeters != null) {
            editor.putLong(
                ACTIVE_MIN_DESTINATION_DISTANCE_METERS,
                java.lang.Double.doubleToRawLongBits(minDestinationDistanceMeters),
            )
        }
        if (pendingCompletionLog != null) editor.putBoolean(ACTIVE_PENDING_COMPLETION_LOG, pendingCompletionLog)
        if (pendingMissedLog != null) editor.putBoolean(ACTIVE_PENDING_MISSED_LOG, pendingMissedLog)
        editor.apply()
    }

    /// Full state for Dart's reconciler (`ActiveTripController`), read on
    /// every foreground resume and on a lightweight poll while foregrounded.
    /// Draining the pending-log flags here (not a separate call) means a
    /// single successful read is enough for Dart to both learn about and
    /// clear a completion/missed-destination event — matching this file's
    /// existing "best-effort, never load-bearing" posture for history
    /// logging (see `ActiveTripController._logHistory`'s doc comment).
    fun activeTripFullState(context: Context): Map<String, Any?> {
        val prefs = preferences(context)
        val pendingCompletion = prefs.getBoolean(ACTIVE_PENDING_COMPLETION_LOG, false)
        val pendingMissed = prefs.getBoolean(ACTIVE_PENDING_MISSED_LOG, false)
        if (pendingCompletion || pendingMissed) {
            prefs.edit()
                .putBoolean(ACTIVE_PENDING_COMPLETION_LOG, false)
                .putBoolean(ACTIVE_PENDING_MISSED_LOG, false)
                .apply()
        }
        return activeTripSnapshot(context) + mapOf(
            "sessionId" to prefs.getString(ACTIVE_SESSION_ID, null),
            "state" to prefs.getString(ACTIVE_STATE, null),
            "currentStationId" to prefs.getString(ACTIVE_CURRENT_STATION_ID, null),
            "nextStationId" to prefs.getString(ACTIVE_NEXT_STATION_ID, null),
            "currentStationIndex" to prefs.getInt(ACTIVE_CURRENT_STATION_INDEX, 0),
            "distanceMeters" to distanceMeters(context),
            "speedKmh" to prefs.optionalFloat(ACTIVE_SPEED_KMH)?.toDouble(),
            "bearingDegrees" to prefs.optionalFloat(ACTIVE_LOCATION_BEARING)?.toDouble(),
            "pendingCompletionLog" to pendingCompletion,
            "pendingMissedDestinationLog" to pendingMissed,
            "locationGap" to locationGap(context),
        )
    }

    fun putDailyRoute(context: Context, data: Map<*, *>) {
        val editor = preferences(context).edit()
            .putBoolean(DAILY_ROUTE_HAS_DATA, true)
            .putString(DAILY_ROUTE_LABEL, data.string("label").orEmpty().clean())
            .putString(DAILY_ROUTE_LINE_STATUS, data.string("lineStatus", "line_status").orEmpty().clean())
            .putBoolean(DAILY_ROUTE_IS_DEMO, data.isDemo())
            .putLong(
                DAILY_ROUTE_UPDATED_AT,
                data.long("updatedAtEpochMs", "updated_at_epoch_ms") ?: System.currentTimeMillis(),
            )
        val departures = (data.value("departures") as? List<*>).orEmpty()
        DAILY_ROUTE_DEPARTURE_TIME.indices.forEach { index ->
            val departure = departures.getOrNull(index) as? Map<*, *>
            editor.putString(DAILY_ROUTE_DEPARTURE_TIME[index], departure?.string("time").orEmpty().clean())
            editor.putString(
                DAILY_ROUTE_DEPARTURE_DESTINATION[index],
                departure?.string("destination").orEmpty().clean(),
            )
        }
        editor.apply()
    }

    fun dailyRouteSnapshot(context: Context): Map<String, Any?> {
        val prefs = preferences(context)
        return mapOf(
            "hasData" to prefs.getBoolean(DAILY_ROUTE_HAS_DATA, false),
            "label" to prefs.getString(DAILY_ROUTE_LABEL, null),
            "lineStatus" to prefs.getString(DAILY_ROUTE_LINE_STATUS, null),
            "isDemo" to prefs.getBoolean(DAILY_ROUTE_IS_DEMO, false),
            "updatedAtEpochMs" to prefs.getLong(DAILY_ROUTE_UPDATED_AT, 0L),
            "departureTimes" to DAILY_ROUTE_DEPARTURE_TIME.map { prefs.getString(it, null).orEmpty() },
            "departureDestinations" to DAILY_ROUTE_DEPARTURE_DESTINATION.map {
                prefs.getString(it, null).orEmpty()
            },
        )
    }

    fun putServiceStatus(context: Context, data: Map<*, *>) {
        val editor = preferences(context).edit()
            .putBoolean(SERVICE_STATUS_HAS_DATA, true)
            .putBoolean(SERVICE_STATUS_IS_DEMO, data.isDemo())
            .putLong(
                SERVICE_STATUS_UPDATED_AT,
                data.long("updatedAtEpochMs", "updated_at_epoch_ms") ?: System.currentTimeMillis(),
            )
        val lines = (data.value("lines") as? List<*>).orEmpty()
        SERVICE_STATUS_LINE_NAME.indices.forEach { index ->
            val line = lines.getOrNull(index) as? Map<*, *>
            editor.putString(SERVICE_STATUS_LINE_NAME[index], line?.string("name").orEmpty().clean())
            editor.putString(SERVICE_STATUS_LINE_STATUS[index], line?.string("status").orEmpty().clean())
        }
        editor.apply()
    }

    fun serviceStatusSnapshot(context: Context): Map<String, Any?> {
        val prefs = preferences(context)
        return mapOf(
            "hasData" to prefs.getBoolean(SERVICE_STATUS_HAS_DATA, false),
            "isDemo" to prefs.getBoolean(SERVICE_STATUS_IS_DEMO, false),
            "updatedAtEpochMs" to prefs.getLong(SERVICE_STATUS_UPDATED_AT, 0L),
            "lineNames" to SERVICE_STATUS_LINE_NAME.map { prefs.getString(it, null).orEmpty() },
            "lineStatuses" to SERVICE_STATUS_LINE_STATUS.map { prefs.getString(it, null).orEmpty() },
        )
    }

    fun lastActivityEvent(context: Context): Map<String, Any?> {
        val prefs = preferences(context)
        return mapOf(
            "type" to prefs.getString(ACTIVITY_LAST_TYPE, null),
            "confidencePercent" to prefs.getInt(ACTIVITY_LAST_CONFIDENCE, 0),
            "occurredAtEpochMs" to prefs.optionalLong(ACTIVITY_LAST_AT),
        )
    }

    private fun SharedPreferences.optionalLong(key: String): Long? =
        if (contains(key)) getLong(key, 0L) else null

    private fun SharedPreferences.optionalFloat(key: String): Float? =
        if (contains(key)) getFloat(key, 0f) else null

    private fun SharedPreferences.optionalDouble(key: String): Double? =
        if (contains(key)) java.lang.Double.longBitsToDouble(getLong(key, 0L)) else null

    private fun String.clean(): String = trim().take(160)

    private fun Map<*, *>.etaLabel(): String {
        string("eta", "estimatedArrival")?.takeIf(String::isNotBlank)?.let { return it }
        val epochMs = long("etaEpochMillis", "eta_epoch_millis") ?: return ""
        return DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(epochMs))
    }

    private fun Map<*, *>.progressValue(): Double {
        double("progress")?.let { return it.coerceIn(0.0, 1.0) }
        val stations = value("stationIds", "station_ids") as? List<*> ?: return 0.0
        if (stations.size <= 1) return 0.0
        val remaining = int("remainingStations", "remaining_stations", "remainingStops")
            ?.coerceIn(0, stations.size - 1)
            ?: return 0.0
        return ((stations.size - 1 - remaining).toDouble() / (stations.size - 1)).coerceIn(0.0, 1.0)
    }
}

internal fun Map<*, *>.hasAny(vararg keys: String): Boolean = keys.any(::containsKey)

internal fun Map<*, *>.value(vararg keys: String): Any? {
    for (key in keys) {
        if (containsKey(key)) return get(key)
    }
    return null
}

internal fun Map<*, *>.string(vararg keys: String): String? = value(*keys)?.toString()

internal fun Map<*, *>.stringIfPresent(vararg keys: String): String? =
    if (hasAny(*keys)) string(*keys).orEmpty() else null

internal fun Map<*, *>.int(vararg keys: String): Int? = when (val raw = value(*keys)) {
    is Number -> raw.toInt()
    is String -> raw.toIntOrNull()
    else -> null
}

internal fun Map<*, *>.intIfPresent(vararg keys: String): Int? =
    if (hasAny(*keys)) int(*keys) else null

internal fun Map<*, *>.long(vararg keys: String): Long? = when (val raw = value(*keys)) {
    is Number -> raw.toLong()
    is String -> raw.toLongOrNull()
    else -> null
}

internal fun Map<*, *>.double(vararg keys: String): Double? = when (val raw = value(*keys)) {
    is Number -> raw.toDouble()
    is String -> raw.toDoubleOrNull()
    else -> null
}

internal fun Map<*, *>.doubleIfPresent(vararg keys: String): Double? =
    if (hasAny(*keys)) double(*keys) else null

internal fun Map<*, *>.boolean(vararg keys: String): Boolean? = when (val raw = value(*keys)) {
    is Boolean -> raw
    is String -> raw.equals("true", ignoreCase = true)
    is Number -> raw.toInt() != 0
    else -> null
}

internal fun Map<*, *>.isDemo(): Boolean =
    boolean("isDemo", "is_demo")
        ?: string("dataSource", "data_source")?.equals("demo", ignoreCase = true)
        ?: false

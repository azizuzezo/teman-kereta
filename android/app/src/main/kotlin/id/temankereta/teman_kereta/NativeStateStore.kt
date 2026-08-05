package id.temankereta.teman_kereta

import android.content.Context
import android.content.SharedPreferences
import java.text.DateFormat
import java.util.Date

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
    const val ACTIVE_LOCATION_AT = "active_trip.location.at_epoch_ms"
    const val ACTIVE_LOCATION_STATUS = "active_trip.location.status"

    const val NEXT_HAS_DATA = "next_departure.has_data"
    const val NEXT_STATION = "next_departure.station"
    const val NEXT_TIME = "next_departure.departure_time"
    const val NEXT_DESTINATION = "next_departure.destination"
    const val NEXT_STATUS = "next_departure.status"
    const val NEXT_IS_DEMO = "next_departure.is_demo"
    const val NEXT_UPDATED_AT = "next_departure.updated_at_epoch_ms"

    const val GEOFENCE_REGISTERED_IDS = "geofence.registered_station_ids"
    const val GEOFENCE_EXPIRES_AT = "geofence.expires_at_epoch_ms"
    const val GEOFENCE_LAST_IDS = "geofence.last_event.station_ids"
    const val GEOFENCE_LAST_TRANSITION = "geofence.last_event.transition"
    const val GEOFENCE_LAST_AT = "geofence.last_event.at_epoch_ms"
    const val GEOFENCE_LAST_ERROR = "geofence.last_event.error"

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
        ACTIVE_LOCATION_AT,
        ACTIVE_LOCATION_STATUS,
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
        editor.apply()
    }

    fun updateActiveTrip(context: Context, data: Map<*, *>) {
        val editor = preferences(context).edit()
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
        data.stringIfPresent("currentStation", "current_station", "currentStationId")?.let {
            editor.putString(ACTIVE_CURRENT_STATION, it.clean())
        }
        data.stringIfPresent("nextStation", "next_station", "nextStationId")?.let {
            editor.putString(ACTIVE_NEXT_STATION, it.clean())
        }
        data.intIfPresent("remainingStations", "remaining_stations", "remainingStops")?.let {
            editor.putInt(ACTIVE_REMAINING, it.coerceAtLeast(0))
        }
        if (data.hasAny("eta", "estimatedArrival", "etaEpochMillis", "eta_epoch_millis")) {
            editor.putString(ACTIVE_ETA, data.etaLabel().clean())
        }
        if (data.hasAny("progress", "stationIds", "station_ids")) {
            editor.putFloat(ACTIVE_PROGRESS, data.progressValue().toFloat())
        }
        if (data.hasAny("isDemo", "is_demo", "dataSource", "data_source")) {
            editor.putBoolean(ACTIVE_IS_DEMO, data.isDemo())
        }
        editor.putLong(
            ACTIVE_UPDATED_AT,
            data.long("updatedAtEpochMs", "updated_at_epoch_ms") ?: System.currentTimeMillis(),
        )
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

    fun lastGeofenceEvent(context: Context): Map<String, Any?> {
        val prefs = preferences(context)
        return mapOf(
            "stationIds" to prefs.getStringSet(GEOFENCE_LAST_IDS, emptySet())!!.toList().sorted(),
            "transition" to prefs.getString(GEOFENCE_LAST_TRANSITION, null),
            "occurredAtEpochMs" to prefs.optionalLong(GEOFENCE_LAST_AT),
            "error" to prefs.getString(GEOFENCE_LAST_ERROR, null),
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

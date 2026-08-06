package id.temankereta.teman_kereta

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.plugin.common.MethodChannel

/**
 * Replaces Teman Kereta's current station geofence scope with a caller-provided subset.
 * There is intentionally no method that discovers or registers every station.
 */
internal class StationGeofenceManager(private val activity: Activity) {
    private val client: GeofencingClient = LocationServices.getGeofencingClient(activity)
    private var operationInFlight = false

    fun register(arguments: Map<*, *>, result: MethodChannel.Result) {
        if (operationInFlight) {
            result.error("GEOFENCE_BUSY", "Operasi geofence lain masih berjalan.", null)
            return
        }

        val missingPermissions = missingPermissions()
        if (missingPermissions.isNotEmpty()) {
            result.error(
                "MISSING_PERMISSION",
                "Izin lokasi belum lengkap untuk geofence stasiun.",
                mapOf("permissions" to missingPermissions),
            )
            return
        }

        val rawStations = arguments.value("stations", "stationGeofences") as? List<*>
        if (rawStations.isNullOrEmpty()) {
            result.error(
                "INVALID_ARGUMENT",
                "Kirim 1–$MAX_STATION_GEOFENCES stasiun yang memang relevan dengan lokasi atau rute aktif.",
                null,
            )
            return
        }
        if (rawStations.size > MAX_STATION_GEOFENCES) {
            result.error(
                "TOO_MANY_GEOFENCES",
                "Maksimal $MAX_STATION_GEOFENCES stasiun per scope; seluruh jaringan tidak boleh didaftarkan sekaligus.",
                mapOf("received" to rawStations.size, "maximum" to MAX_STATION_GEOFENCES),
            )
            return
        }

        val expirationMs = arguments.long("expirationDurationMs", "expiration_duration_ms")
            ?: DEFAULT_EXPIRATION_MS
        if (expirationMs !in MIN_EXPIRATION_MS..MAX_EXPIRATION_MS) {
            result.error(
                "INVALID_ARGUMENT",
                "expirationDurationMs harus antara $MIN_EXPIRATION_MS dan $MAX_EXPIRATION_MS.",
                null,
            )
            return
        }

        val stations = try {
            rawStations.mapIndexed { index, raw -> parseStation(index, raw) }
        } catch (error: IllegalArgumentException) {
            result.error("INVALID_ARGUMENT", error.message, null)
            return
        }
        if (stations.map { it.id }.toSet().size != stations.size) {
            result.error("INVALID_ARGUMENT", "stationId dalam scope harus unik.", null)
            return
        }

        val geofences = stations.map { station ->
            Geofence.Builder()
                .setRequestId(requestId(station.id))
                .setCircularRegion(station.latitude, station.longitude, station.radiusMeters)
                .setExpirationDuration(expirationMs)
                .setTransitionTypes(
                    Geofence.GEOFENCE_TRANSITION_ENTER or
                        Geofence.GEOFENCE_TRANSITION_EXIT or
                        Geofence.GEOFENCE_TRANSITION_DWELL,
                )
                // Lets the confidence engine tell "briefly passing near a station"
                // apart from "actually stopped there" (PRD §9/§30's atStation phase).
                .setLoiteringDelay(DWELL_LOITERING_DELAY_MS)
                .build()
        }
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofences)
            .build()

        operationInFlight = true
        // Removing the previous PendingIntent scope first ensures the registered set is exactly
        // the explicit list above, not an ever-growing accumulation of stations.
        client.removeGeofences(geofencePendingIntent()).addOnCompleteListener { removeTask ->
            if (!removeTask.isSuccessful) {
                operationInFlight = false
                sendTaskError(result, "GEOFENCE_REPLACE_FAILED", removeTask.exception)
                return@addOnCompleteListener
            }

            try {
                client.addGeofences(request, geofencePendingIntent()).addOnCompleteListener { addTask ->
                    operationInFlight = false
                    if (addTask.isSuccessful) {
                        val expiresAt = System.currentTimeMillis() + expirationMs
                        NativeStateStore.preferences(activity).edit()
                            .putStringSet(NativeStateStore.GEOFENCE_REGISTERED_IDS, stations.map { it.id }.toSet())
                            .putString(
                                NativeStateStore.GEOFENCE_DETAILS_JSON,
                                NativeStateStore.encodeGeofenceDetails(
                                    stations.map {
                                        NativeStateStore.GeofenceDetail(
                                            it.id,
                                            it.latitude,
                                            it.longitude,
                                            it.radiusMeters,
                                        )
                                    },
                                ),
                            )
                            .putLong(NativeStateStore.GEOFENCE_EXPIRES_AT, expiresAt)
                            .apply()
                        result.success(
                            mapOf(
                                "registered" to true,
                                "stationIds" to stations.map { it.id },
                                "count" to stations.size,
                                "expiresAtEpochMs" to expiresAt,
                                "scope" to "providedStationsOnly",
                            ),
                        )
                    } else {
                        sendTaskError(result, "GEOFENCE_REGISTRATION_FAILED", addTask.exception)
                    }
                }
            } catch (error: SecurityException) {
                operationInFlight = false
                result.error("MISSING_PERMISSION", "Izin lokasi berubah saat geofence didaftarkan.", error.message)
            }
        }
    }

    fun unregister(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (operationInFlight) {
            result.error("GEOFENCE_BUSY", "Operasi geofence lain masih berjalan.", null)
            return
        }

        val requestedIds = (arguments?.value("stationIds", "station_ids") as? List<*>)
            ?.mapNotNull { it?.toString()?.trim()?.takeIf(String::isNotEmpty) }
            ?.distinct()
            .orEmpty()

        operationInFlight = true
        val task = if (requestedIds.isEmpty()) {
            client.removeGeofences(geofencePendingIntent())
        } else {
            client.removeGeofences(requestedIds.map(::requestId))
        }
        task.addOnCompleteListener { removeTask ->
            operationInFlight = false
            if (!removeTask.isSuccessful) {
                sendTaskError(result, "GEOFENCE_REMOVAL_FAILED", removeTask.exception)
                return@addOnCompleteListener
            }

            val prefs = NativeStateStore.preferences(activity)
            val remaining = if (requestedIds.isEmpty()) {
                emptySet()
            } else {
                prefs.getStringSet(NativeStateStore.GEOFENCE_REGISTERED_IDS, emptySet())
                    .orEmpty() - requestedIds.toSet()
            }
            val remainingDetails = NativeStateStore.geofenceDetails(activity)
                .filter { it.id in remaining }
            prefs.edit()
                .putStringSet(NativeStateStore.GEOFENCE_REGISTERED_IDS, remaining)
                .putString(
                    NativeStateStore.GEOFENCE_DETAILS_JSON,
                    NativeStateStore.encodeGeofenceDetails(remainingDetails),
                )
                .apply {
                    if (remaining.isEmpty()) remove(NativeStateStore.GEOFENCE_EXPIRES_AT)
                }
                .apply()
            result.success(
                mapOf(
                    "removed" to true,
                    "removedStationIds" to requestedIds,
                    "remainingStationIds" to remaining.toList().sorted(),
                ),
            )
        }
    }

    fun registeredStationGeofences(): Map<String, Any?> {
        val prefs = NativeStateStore.preferences(activity)
        return mapOf(
            "stationIds" to prefs.getStringSet(NativeStateStore.GEOFENCE_REGISTERED_IDS, emptySet())
                .orEmpty().toList().sorted(),
            "expiresAtEpochMs" to if (prefs.contains(NativeStateStore.GEOFENCE_EXPIRES_AT)) {
                prefs.getLong(NativeStateStore.GEOFENCE_EXPIRES_AT, 0L)
            } else {
                null
            },
            "scope" to "providedStationsOnly",
        )
    }

    private fun parseStation(index: Int, raw: Any?): StationGeofence {
        val map = raw as? Map<*, *>
            ?: throw IllegalArgumentException("stations[$index] harus berupa object.")
        val id = map.string("stationId", "station_id", "id")?.trim().orEmpty()
        if (!STATION_ID_PATTERN.matches(id)) {
            throw IllegalArgumentException(
                "stations[$index].stationId wajib 1–80 karakter: huruf, angka, titik, garis bawah, titik dua, atau tanda hubung.",
            )
        }
        val latitude = map.double("latitude", "lat")
            ?: throw IllegalArgumentException("stations[$index].latitude wajib berupa angka.")
        val longitude = map.double("longitude", "lng", "lon")
            ?: throw IllegalArgumentException("stations[$index].longitude wajib berupa angka.")
        val radius = map.double("radiusMeters", "radius_meters", "radius")
            ?: DEFAULT_RADIUS_METERS.toDouble()

        if (!latitude.isFinite() || latitude !in -90.0..90.0) {
            throw IllegalArgumentException("stations[$index].latitude di luar rentang -90 hingga 90.")
        }
        if (!longitude.isFinite() || longitude !in -180.0..180.0) {
            throw IllegalArgumentException("stations[$index].longitude di luar rentang -180 hingga 180.")
        }
        if (!radius.isFinite() || radius !in MIN_RADIUS_METERS..MAX_RADIUS_METERS) {
            throw IllegalArgumentException(
                "stations[$index].radiusMeters harus antara $MIN_RADIUS_METERS dan $MAX_RADIUS_METERS meter.",
            )
        }
        return StationGeofence(id, latitude, longitude, radius.toFloat())
    }

    private fun missingPermissions(): List<String> = buildList {
        if (activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            activity.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }
    }

    private fun geofencePendingIntent(): PendingIntent = StationGeofenceReceiver.pendingIntent(activity)

    private fun sendTaskError(result: MethodChannel.Result, code: String, error: Exception?) {
        val apiError = error as? ApiException
        result.error(
            code,
            apiError?.let { GeofenceStatusCodes.getStatusCodeString(it.statusCode) }
                ?: error?.message
                ?: "Operasi geofence gagal tanpa detail dari Google Play services.",
            apiError?.let { mapOf("statusCode" to it.statusCode) },
        )
    }

    private fun requestId(stationId: String): String = "$REQUEST_ID_PREFIX$stationId"

    private data class StationGeofence(
        val id: String,
        val latitude: Double,
        val longitude: Double,
        val radiusMeters: Float,
    )

    companion object {
        private const val REQUEST_ID_PREFIX = "station:"
        private const val MAX_STATION_GEOFENCES = 20
        private const val DEFAULT_RADIUS_METERS = 250f
        private const val MIN_RADIUS_METERS = 100.0
        private const val MAX_RADIUS_METERS = 2_000.0
        private const val MIN_EXPIRATION_MS = 15 * 60 * 1_000L
        private const val DEFAULT_EXPIRATION_MS = 24 * 60 * 60 * 1_000L
        private const val MAX_EXPIRATION_MS = 7 * 24 * 60 * 60 * 1_000L
        private const val DWELL_LOITERING_DELAY_MS = 90_000
        private val STATION_ID_PATTERN = Regex("^[A-Za-z0-9._:-]{1,80}$")
    }
}

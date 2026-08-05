package id.temankereta.teman_kereta

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var geofenceManager: StationGeofenceManager
    private lateinit var activityRecognitionManager: ActivityRecognitionManager
    private var pendingActivityPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        geofenceManager = StationGeofenceManager(this)
        activityRecognitionManager = ActivityRecognitionManager(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL)
            .setMethodCallHandler(::handleNativeMethod)
    }

    private fun handleNativeMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getNativeCapabilities" -> result.success(nativeCapabilities())
            "getPermissionStatus" -> result.success(permissionStatus())
            "getActiveTripSnapshot" -> result.success(NativeStateStore.activeTripSnapshot(this))
            "getLastGeofenceEvent" -> result.success(NativeStateStore.lastGeofenceEvent(this))
            "getLastActivityEvent" -> result.success(NativeStateStore.lastActivityEvent(this))
            "getRegisteredStationGeofences" -> result.success(geofenceManager.registeredStationGeofences())
            "startActiveTrip" -> startActiveTrip(call.argumentsMap(), result)
            "updateActiveTrip" -> updateActiveTrip(call.argumentsMap(), result)
            "stopActiveTrip" -> stopActiveTrip(result)
            "updateWidget" -> updateWidget(call.argumentsMap(), result)
            "updateNextDepartureWidget" -> updateNextDepartureWidget(call.argumentsMap(), result)
            "updateActiveTripWidget" -> updateActiveTripWidget(call.argumentsMap(), result)
            "registerStationGeofences" -> {
                val arguments = call.argumentsMap()
                if (arguments == null) {
                    result.invalidArguments("registerStationGeofences memerlukan object arguments.")
                } else {
                    geofenceManager.register(arguments, result)
                }
            }
            "unregisterStationGeofences" -> geofenceManager.unregister(call.argumentsMap(), result)
            "requestActivityRecognitionUpdates" -> requestActivityRecognitionUpdates(result)
            "stopActivityRecognitionUpdates" -> activityRecognitionManager.stopTransitionUpdates(result)
            else -> result.notImplemented()
        }
    }

    private fun requestActivityRecognitionUpdates(result: MethodChannel.Result) {
        if (activityRecognitionManager.hasPermission()) {
            activityRecognitionManager.startTransitionUpdates(result)
            return
        }
        if (pendingActivityPermissionResult != null) {
            result.error(
                "ACTIVITY_RECOGNITION_BUSY",
                "Permintaan izin pengenalan aktivitas lain sedang berlangsung.",
                null,
            )
            return
        }
        pendingActivityPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            ACTIVITY_RECOGNITION_PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != ACTIVITY_RECOGNITION_PERMISSION_REQUEST_CODE) return
        val result = pendingActivityPermissionResult ?: return
        pendingActivityPermissionResult = null
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            activityRecognitionManager.startTransitionUpdates(result)
        } else {
            result.error("MISSING_PERMISSION", "Izin pengenalan aktivitas ditolak.", null)
        }
    }

    private fun startActiveTrip(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.invalidArguments("startActiveTrip memerlukan object arguments.")
            return
        }
        val tripId = arguments.string("tripId", "trip_id")?.trim().orEmpty()
        if (tripId.isEmpty() || tripId.length > 160) {
            result.invalidArguments("tripId wajib diisi dan maksimal 160 karakter.")
            return
        }
        if (!hasForegroundLocationPermission()) {
            result.error(
                "MISSING_PERMISSION",
                "Izin lokasi saat aplikasi digunakan diperlukan sebelum perjalanan dimulai.",
                mapOf(
                    "permissions" to listOf(
                        Manifest.permission.ACCESS_COARSE_LOCATION,
                        Manifest.permission.ACCESS_FINE_LOCATION,
                    ),
                    "requestAfterExplanation" to true,
                ),
            )
            return
        }

        try {
            NativeStateStore.startActiveTrip(this, arguments)
            TemanKeretaWidgetUpdater.updateActiveTrip(this)
            ActiveTripLocationService.start(this)
            val warnings = buildList {
                if (!hasNotificationPermission()) add(Manifest.permission.POST_NOTIFICATIONS)
            }
            result.success(
                mapOf(
                    "started" to true,
                    "tripId" to tripId,
                    "foregroundService" to true,
                    "warnings" to warnings,
                ),
            )
        } catch (error: RuntimeException) {
            NativeStateStore.clearActiveTrip(this)
            TemanKeretaWidgetUpdater.updateActiveTrip(this)
            result.error(
                "FOREGROUND_SERVICE_START_FAILED",
                "Perjalanan tidak dapat dimulai oleh Android pada kondisi aplikasi saat ini.",
                error.message,
            )
        }
    }

    private fun updateActiveTrip(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.invalidArguments("updateActiveTrip memerlukan object arguments.")
            return
        }
        if (!NativeStateStore.preferences(this).getBoolean(NativeStateStore.ACTIVE, false)) {
            result.error("NO_ACTIVE_TRIP", "Tidak ada perjalanan aktif untuk diperbarui.", null)
            return
        }
        if (!hasForegroundLocationPermission()) {
            result.error(
                "MISSING_PERMISSION",
                "Izin lokasi telah dicabut; foreground service tidak dapat diperbarui.",
                permissionStatus(),
            )
            return
        }

        try {
            NativeStateStore.updateActiveTrip(this, arguments)
            TemanKeretaWidgetUpdater.updateActiveTrip(this)
            ActiveTripLocationService.update(this)
            result.success(mapOf("updated" to true))
        } catch (error: RuntimeException) {
            result.error(
                "FOREGROUND_SERVICE_UPDATE_FAILED",
                "Ringkasan perjalanan tersimpan, tetapi foreground service gagal diperbarui.",
                error.message,
            )
        }
    }

    private fun stopActiveTrip(result: MethodChannel.Result) {
        NativeStateStore.clearActiveTrip(this)
        TemanKeretaWidgetUpdater.updateActiveTrip(this)
        ActiveTripLocationService.stop(this)
        result.success(mapOf("stopped" to true))
    }

    private fun updateWidget(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.invalidArguments("updateWidget memerlukan object arguments.")
            return
        }
        val widget = arguments.string("widget", "type")?.trim().orEmpty()
        val data = (arguments.value("data") as? Map<*, *>) ?: arguments
        when (widget) {
            "nextDeparture", "next_departure" -> updateNextDepartureWidget(data, result)
            "activeTrip", "active_trip" -> updateActiveTripWidget(data, result)
            "dailyRoute", "daily_route" -> updateDailyRouteWidget(data, result)
            "serviceStatus", "service_status" -> updateServiceStatusWidget(data, result)
            "" -> {
                // Backward-compatible shape used by the first local Dart bridge: an active-trip
                // payload was sent directly, before the `widget` discriminator was introduced.
                if (data.hasAny("tripId", "trip_id", "sessionId")) {
                    updateActiveTripWidget(data, result)
                } else {
                    result.invalidArguments(
                        "widget harus bernilai nextDeparture, activeTrip, dailyRoute, atau serviceStatus.",
                    )
                }
            }
            else -> result.invalidArguments(
                "widget harus bernilai nextDeparture, activeTrip, dailyRoute, atau serviceStatus.",
            )
        }
    }

    private fun updateDailyRouteWidget(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.invalidArguments("Data widget rute harian wajib diisi.")
            return
        }
        val label = arguments.string("label")?.trim().orEmpty()
        if (label.isEmpty()) {
            result.invalidArguments("label wajib diisi.")
            return
        }
        NativeStateStore.putDailyRoute(this, arguments)
        TemanKeretaWidgetUpdater.updateDailyRoute(this)
        result.success(mapOf("updated" to true, "widget" to "dailyRoute", "isDemo" to arguments.isDemo()))
    }

    private fun updateServiceStatusWidget(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.invalidArguments("Data widget status jalur wajib diisi.")
            return
        }
        NativeStateStore.putServiceStatus(this, arguments)
        TemanKeretaWidgetUpdater.updateServiceStatus(this)
        result.success(mapOf("updated" to true, "widget" to "serviceStatus", "isDemo" to arguments.isDemo()))
    }

    private fun updateNextDepartureWidget(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.invalidArguments("Data widget kereta berikutnya wajib diisi.")
            return
        }
        val station = arguments.string("station", "stationName", "station_name")?.trim().orEmpty()
        val departureTime = arguments.string("departureTime", "departure_time", "time")?.trim().orEmpty()
        val destination = arguments.string("destination", "destinationName")?.trim().orEmpty()
        if (station.isEmpty() || departureTime.isEmpty() || destination.isEmpty()) {
            result.invalidArguments("station, departureTime, dan destination wajib diisi.")
            return
        }

        NativeStateStore.putNextDeparture(this, arguments)
        TemanKeretaWidgetUpdater.updateNextDeparture(this)
        result.success(
            mapOf(
                "updated" to true,
                "widget" to "nextDeparture",
                "isDemo" to arguments.isDemo(),
            ),
        )
    }

    private fun updateActiveTripWidget(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.invalidArguments("Data widget perjalanan aktif wajib diisi.")
            return
        }
        if (!NativeStateStore.preferences(this).getBoolean(NativeStateStore.ACTIVE, false)) {
            result.error("NO_ACTIVE_TRIP", "Tidak ada perjalanan aktif untuk ditampilkan.", null)
            return
        }
        NativeStateStore.updateActiveTrip(this, arguments)
        TemanKeretaWidgetUpdater.updateActiveTrip(this)
        result.success(
            mapOf(
                "updated" to true,
                "widget" to "activeTrip",
                "isDemo" to NativeStateStore.preferences(this)
                    .getBoolean(NativeStateStore.ACTIVE_IS_DEMO, false),
            ),
        )
    }

    private fun nativeCapabilities(): Map<String, Any> = mapOf(
        "channel" to NATIVE_CHANNEL,
        "foregroundLocationService" to true,
        "homeScreenWidgets" to listOf("nextDeparture", "activeTrip", "dailyRoute", "serviceStatus"),
        "stationGeofences" to mapOf(
            "providedStationsOnly" to true,
            "maximumPerScope" to 20,
            "defaultExpirationHours" to 24,
        ),
        "activityRecognition" to mapOf(
            "monitoredTypes" to listOf("in_vehicle", "on_foot", "still"),
            "transitionApi" to true,
        ),
        "deepLinks" to listOf(
            "temankereta://app/departures",
            "temankereta://app/active-trip",
            "temankereta://app/home",
        ),
        "automaticDeployment" to false,
        "automaticNetworkRefresh" to false,
    )

    private fun permissionStatus(): Map<String, Any> {
        val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val background = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        val notifications = hasNotificationPermission()
        return mapOf(
            "fineLocation" to fine,
            "coarseLocation" to coarse,
            "foregroundLocation" to (fine || coarse),
            "backgroundLocation" to background,
            "notifications" to notifications,
            "activityRecognition" to activityRecognitionManager.hasPermission(),
            "canStartActiveTrip" to (fine || coarse),
            "canRegisterStationGeofences" to (fine && background),
            "requestAfterExplanation" to true,
            "backgroundPermissionMustBeRequestedSeparately" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R),
        )
    }

    private fun hasForegroundLocationPermission(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun MethodCall.argumentsMap(): Map<*, *>? = arguments as? Map<*, *>

    private fun MethodChannel.Result.invalidArguments(message: String) {
        error("INVALID_ARGUMENT", message, null)
    }

    companion object {
        const val NATIVE_CHANNEL = "id.temankereta.teman_kereta/native"
        private const val ACTIVITY_RECOGNITION_PERMISSION_REQUEST_CODE = 52_201
    }
}

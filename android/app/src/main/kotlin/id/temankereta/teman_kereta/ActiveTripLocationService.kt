package id.temankereta.teman_kereta

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * Continuous, fixed-accuracy GPS tracking for an active trip — replaces the
 * old adaptive 4-tier `SamplingProfile`/`LocationManager` design (the
 * "adaptif" this whole feature exists to get rid of) with
 * `FusedLocationProviderClient` at a single fixed `PRIORITY_HIGH_ACCURACY`
 * request. The one remaining manual override is `lowBatteryMode` — a
 * per-trip toggle the rider chooses explicitly, not automatic backoff.
 *
 * Every accepted fix is handed to [TripProgressEngine], which owns the trip
 * state machine (station advancement, notifications) — this class only
 * owns the GPS plumbing and the fix-quality gates (accuracy ceiling, jitter
 * floor, implausible-speed rejection) that decide what counts as "accepted".
 */
class ActiveTripLocationService : Service() {
    private lateinit var fusedClient: FusedLocationProviderClient
    private lateinit var notificationManager: NotificationManager
    private var progressEngine: TripProgressEngine? = null
    private var currentlyLowBattery: Boolean? = null
    private var explicitlyStopped = false

    private var lastAcceptedLat: Double? = null
    private var lastAcceptedLng: Double? = null
    private var lastAcceptedAtMs: Long? = null

    /// Wall-clock time of the last fix this service actually received —
    /// distinct from [lastAcceptedAtMs] (the *fix's own* timestamp, which
    /// only advances for fixes that pass the quality gates). The watchdog
    /// below measures silence against this, so a stream of rejected fixes
    /// still counts as the receiver being alive.
    private var lastFixReceivedAtMs: Long = 0L
    private val watchdogHandler = Handler(Looper.getMainLooper())
    private val watchdog = object : Runnable {
        override fun run() {
            checkForStalledUpdates()
            watchdogHandler.postDelayed(this, WATCHDOG_INTERVAL_MS)
        }
    }

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let(::handleLocation)
        }
    }

    override fun onCreate() {
        super.onCreate()
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        // Restore the last accepted fix from persisted state. Without this,
        // a service that Android restarted mid-trip starts with no
        // reference point, so the first fix back contributes no distance
        // and — worse — the signal-gap detector below can't see that
        // anything was ever missed.
        val prefs = NativeStateStore.preferences(this)
        if (prefs.contains(NativeStateStore.ACTIVE_LOCATION_AT)) {
            lastAcceptedLat = prefs.storedDouble(NativeStateStore.ACTIVE_LOCATION_LATITUDE)
            lastAcceptedLng = prefs.storedDouble(NativeStateStore.ACTIVE_LOCATION_LONGITUDE)
            lastAcceptedAtMs = prefs.getLong(NativeStateStore.ACTIVE_LOCATION_AT, 0L).takeIf { it > 0L }
        }
    }

    private fun android.content.SharedPreferences.storedDouble(key: String): Double? =
        if (contains(key)) java.lang.Double.longBitsToDouble(getLong(key, 0L)) else null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopActiveTrip()
            return START_NOT_STICKY
        }

        val prefs = NativeStateStore.preferences(this)
        if (!prefs.getBoolean(NativeStateStore.ACTIVE, false)) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (!hasForegroundLocationPermission()) {
            prefs.edit().putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "permission_missing").apply()
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (!enterForeground()) {
            prefs.edit().putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "foreground_service_unavailable").apply()
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (progressEngine == null) {
            progressEngine = TripProgressEngine(this, ::onStationAdvanced)
        }
        // The manual "Perbarui lokasi" button. Deliberately additive: it
        // rebuilds the subscription and forces one high-accuracy fix
        // through the exact same pipeline every automatic fix goes through.
        // It is never the thing progress depends on. Handled here rather
        // than as an early return so a refresh that happens to be the call
        // that (re)starts this service still enters the foreground first —
        // Android kills a `startForegroundService()` that doesn't.
        val isRefresh = intent?.action == ACTION_REFRESH
        requestLocationUpdatesIfProfileChanged(forceRestart = isRefresh)
        startWatchdog()
        if (isRefresh) {
            requestSingleHighAccuracyFix()
        }
        return START_STICKY
    }

    /**
     * Re-renders everything that displays the trip's current position from
     * [NativeStateStore], after this service's own engine moved it. The
     * ongoing notification is a plain `notify()` with the same id, which
     * updates the foreground notification in place without restarting the
     * service.
     */
    private fun onStationAdvanced() {
        try {
            notificationManager.notify(NOTIFICATION_ID, buildNotification())
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS revoked mid-trip — never crash tracking for it.
        }
        TemanKeretaWidgetUpdater.updateActiveTrip(this)
    }

    /**
     * The anti-stuck guard. `FusedLocationProviderClient` can stop
     * delivering to a long-lived callback without ever reporting an error —
     * a doze transition, a provider restart, the OS killing Play services'
     * process — which is exactly what a rider sees as "GPS stuck at
     * Citayam while I'm already at Cilebut": the trip is still running, the
     * callback is just never called again. Nothing in the old design ever
     * noticed. This does: after [STALE_FIX_THRESHOLD_MS] of silence it
     * flags the trip as having lost signal, tears the subscription down and
     * builds a fresh one, and asks for a one-shot fix to prime it.
     */
    private fun startWatchdog() {
        watchdogHandler.removeCallbacks(watchdog)
        watchdogHandler.postDelayed(watchdog, WATCHDOG_INTERVAL_MS)
    }

    private fun checkForStalledUpdates() {
        if (!NativeStateStore.preferences(this).getBoolean(NativeStateStore.ACTIVE, false)) return
        if (!hasForegroundLocationPermission()) return
        // 0 means "we have never subscribed", not "silent forever" — there
        // is nothing to compare against yet.
        val lastFixAt = lastFixReceivedAtMs
        if (lastFixAt == 0L) return
        if (System.currentTimeMillis() - lastFixAt < STALE_FIX_THRESHOLD_MS) return
        // Rebuild first, then flag: rebuilding writes
        // "waiting_for_location" itself, and the rider is better served by
        // "sinyal hilang" standing until a real fix actually lands (only
        // `handleLocation` clears it back to "tracking"). The rebuild also
        // resets the silence clock, so a genuine dead zone retries about
        // every STALE_FIX_THRESHOLD_MS rather than every watchdog tick.
        requestLocationUpdatesIfProfileChanged(forceRestart = true)
        requestSingleHighAccuracyFix()
        NativeStateStore.preferences(this).edit()
            .putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "signal_lost")
            .apply()
    }

    /**
     * One-shot high-accuracy fix, fed through [handleLocation] like any
     * other. Used both by the watchdog above and by the rider's own
     * "Perbarui lokasi" button — a fix obtained this way is not special in
     * any way once it arrives, which is the point: the manual button can
     * only ever speed up what automatic tracking would have concluded, it
     * can never assert progress on its own.
     */
    private fun requestSingleHighAccuracyFix() {
        if (!hasForegroundLocationPermission()) return
        try {
            val request = CurrentLocationRequest.Builder()
                .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                .setMaxUpdateAgeMillis(SINGLE_FIX_MAX_AGE_MS)
                .setDurationMillis(SINGLE_FIX_TIMEOUT_MS)
                .build()
            fusedClient.getCurrentLocation(request, null)
                .addOnSuccessListener { location -> location?.let(::handleLocation) }
        } catch (_: SecurityException) {
            // Permission revoked between the check above and the call.
        }
    }

    /**
     * Notices that this fix arrived after a long silence *and* from a
     * meaningfully different place than the last one — i.e. the rider kept
     * travelling while the app could not see them. Persisted for Dart to
     * ask "Kami mendeteksi lokasi kamu berbeda dari lokasi terakhir. Apakah
     * kamu masih di kereta?" on the next foreground resume.
     *
     * Recording it is all this does. `TripProgressEngine`'s catch-up gate
     * resumes the trip from wherever the rider actually is regardless of
     * whether that question is ever answered — the prompt exists to confirm
     * an assumption, never to unblock one.
     */
    private fun recordSignalGapIfAny(location: Location) {
        val previousLat = lastAcceptedLat ?: return
        val previousLng = lastAcceptedLng ?: return
        val previousAtMs = lastAcceptedAtMs ?: return
        val gapMs = location.time - previousAtMs
        if (gapMs < SIGNAL_GAP_THRESHOLD_MS) return
        val movedMeters = GeoMath.haversineMeters(previousLat, previousLng, location.latitude, location.longitude)
        if (movedMeters < SIGNAL_GAP_MIN_DISTANCE_METERS) return
        NativeStateStore.recordLocationGap(
            this,
            fromLatitude = previousLat,
            fromLongitude = previousLng,
            fromAtEpochMs = previousAtMs,
            toLatitude = location.latitude,
            toLongitude = location.longitude,
            toAtEpochMs = location.time,
            distanceMeters = movedMeters,
        )
    }

    private fun handleLocation(location: Location) {
        lastFixReceivedAtMs = System.currentTimeMillis()
        recordSignalGapIfAny(location)
        NativeStateStore.preferences(this).edit()
            .putLong(NativeStateStore.ACTIVE_LOCATION_LATITUDE, java.lang.Double.doubleToRawLongBits(location.latitude))
            .putLong(NativeStateStore.ACTIVE_LOCATION_LONGITUDE, java.lang.Double.doubleToRawLongBits(location.longitude))
            .putFloat(NativeStateStore.ACTIVE_LOCATION_ACCURACY, location.accuracy)
            .putFloat(NativeStateStore.ACTIVE_LOCATION_SPEED, if (location.hasSpeed()) location.speed.coerceAtLeast(0f) else 0f)
            .apply {
                if (location.hasBearing()) putFloat(NativeStateStore.ACTIVE_LOCATION_BEARING, location.bearing)
            }
            .putLong(NativeStateStore.ACTIVE_LOCATION_AT, location.time)
            .putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "tracking")
            .apply()

        if (location.accuracy > ACCURACY_CEILING_METERS || location.accuracy <= 0f) {
            return
        }

        val prevLat = lastAcceptedLat
        val prevLng = lastAcceptedLng
        val prevAtMs = lastAcceptedAtMs
        var deltaMeters = 0.0
        // Fallback for when the fix carries no usable speed of its own
        // (`location.hasSpeed()` false, or a device/emulator that reports a
        // flat 0 regardless of real movement) — derived from how far the
        // accepted delta above covered in how long, the same "distance/time"
        // stand-in the old Dart-side hop estimate used, just continuous now.
        var derivedSpeedMps: Double? = null
        if (prevLat != null && prevLng != null && prevAtMs != null) {
            val rawDelta = GeoMath.haversineMeters(prevLat, prevLng, location.latitude, location.longitude)
            val elapsedSeconds = (location.time - prevAtMs) / 1000.0
            if (elapsedSeconds > 0) {
                val impliedSpeedMps = rawDelta / elapsedSeconds
                if (impliedSpeedMps > IMPLAUSIBLE_SPEED_METERS_PER_SECOND) {
                    // Almost certainly a GPS jump/spoof artifact, not real
                    // movement — drop the delta but still accept the fix as
                    // the new baseline so a single bad sample can't strand
                    // every future fix against a stale reference point.
                    deltaMeters = 0.0
                } else {
                    val jitterFloor = maxOf(JITTER_FLOOR_METERS.toDouble(), location.accuracy.toDouble())
                    deltaMeters = if (rawDelta >= jitterFloor) rawDelta else 0.0
                    if (deltaMeters > 0) {
                        derivedSpeedMps = impliedSpeedMps
                    }
                }
            }
        }
        lastAcceptedLat = location.latitude
        lastAcceptedLng = location.longitude
        lastAcceptedAtMs = location.time

        // Deliberately not a bare `> 0f`: some providers (confirmed live —
        // the Android emulator's mock GPS) report a nonzero-but-negligible
        // speed (~1e-13 m/s) while genuinely stationary, which is float
        // noise, not a real reading — trusting it would mean never falling
        // back to the derived speed below. MIN_USABLE_REPORTED_SPEED_MPS is
        // comfortably below any real walking/train speed, well above noise.
        val hasUsableReportedSpeed =
            location.hasSpeed() && location.speed > MIN_USABLE_REPORTED_SPEED_MPS
        progressEngine?.onAcceptedFix(
            location,
            deltaMeters,
            fallbackSpeedMps = if (hasUsableReportedSpeed) null else derivedSpeedMps,
        )
    }

    override fun onDestroy() {
        watchdogHandler.removeCallbacks(watchdog)
        fusedClient.removeLocationUpdates(locationCallback)
        progressEngine?.shutdown()
        progressEngine = null
        currentlyLowBattery = null
        lastAcceptedLat = null
        lastAcceptedLng = null
        lastAcceptedAtMs = null
        lastFixReceivedAtMs = 0L
        if (explicitlyStopped) {
            NativeStateStore.clearActiveTrip(this)
            TemanKeretaWidgetUpdater.updateActiveTrip(this)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun enterForeground(): Boolean {
        return try {
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalStateException) {
            false
        }
    }

    private fun buildNotification(): Notification {
        val prefs = NativeStateStore.preferences(this)
        val isDemo = prefs.getBoolean(NativeStateStore.ACTIVE_IS_DEMO, false)
        val currentStation = prefs.getString(NativeStateStore.ACTIVE_CURRENT_STATION, null).orEmpty()
        val nextStation = prefs.getString(NativeStateStore.ACTIVE_NEXT_STATION, null).orEmpty()
        val remaining = prefs.getInt(NativeStateStore.ACTIVE_REMAINING, 0).coerceAtLeast(0)
        val title = getString(
            if (isDemo) R.string.active_trip_notification_demo_title else R.string.active_trip_notification_title,
        )
        val content = when {
            currentStation.isNotBlank() && nextStation.isNotBlank() -> getString(
                R.string.active_trip_notification_progress,
                currentStation,
                nextStation,
                remaining,
            )
            nextStation.isNotBlank() -> getString(R.string.active_trip_notification_next, nextStation, remaining)
            else -> getString(R.string.active_trip_notification_tracking)
        }

        val openIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("temankereta://app/active-trip?source=notification"),
            this,
            MainActivity::class.java,
        ).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this,
            OPEN_REQUEST_CODE,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val stopIntent = Intent(this, ActiveTripLocationService::class.java).apply { action = ACTION_STOP }
        val stopPendingIntent = PendingIntent.getService(
            this,
            STOP_REQUEST_CODE,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val publicVersion = newNotificationBuilder()
            .setSmallIcon(R.drawable.ic_stat_tk)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(getString(R.string.active_trip_notification_generic))
            .build()

        val builder = newNotificationBuilder()
            .setSmallIcon(R.drawable.ic_stat_tk)
            .setContentTitle(title)
            .setContentText(content)
            .setContentIntent(openPendingIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .addAction(
                Notification.Action.Builder(null, getString(R.string.active_trip_notification_stop), stopPendingIntent).build(),
            )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun newNotificationBuilder(): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            getString(R.string.active_trip_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.active_trip_channel_description)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun requestLocationUpdatesIfProfileChanged(forceRestart: Boolean = false) {
        if (!hasForegroundLocationPermission()) return
        val lowBattery = NativeStateStore.lowBatteryMode(this)
        if (lowBattery == currentlyLowBattery && !forceRestart) {
            return
        }
        val request = if (lowBattery) {
            LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, LOW_BATTERY_INTERVAL_MS)
                .setMinUpdateIntervalMillis(LOW_BATTERY_MIN_INTERVAL_MS)
                .build()
        } else {
            LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, HIGH_ACCURACY_INTERVAL_MS)
                .setMinUpdateIntervalMillis(HIGH_ACCURACY_MIN_INTERVAL_MS)
                .setMinUpdateDistanceMeters(0f)
                .build()
        }
        try {
            fusedClient.removeLocationUpdates(locationCallback)
            fusedClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())
            currentlyLowBattery = lowBattery
            lastFixReceivedAtMs = System.currentTimeMillis()
            NativeStateStore.preferences(this).edit()
                .putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "waiting_for_location")
                .apply()
        } catch (_: SecurityException) {
            NativeStateStore.preferences(this).edit()
                .putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "permission_missing")
                .apply()
            stopSelf()
        }
    }

    private fun hasForegroundLocationPermission(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun stopActiveTrip() {
        explicitlyStopped = true
        watchdogHandler.removeCallbacks(watchdog)
        fusedClient.removeLocationUpdates(locationCallback)
        NativeStateStore.clearActiveTrip(this)
        TemanKeretaWidgetUpdater.updateActiveTrip(this)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    companion object {
        const val ACTION_START = "id.temankereta.teman_kereta.action.START_ACTIVE_TRIP"
        const val ACTION_UPDATE = "id.temankereta.teman_kereta.action.UPDATE_ACTIVE_TRIP"
        const val ACTION_STOP = "id.temankereta.teman_kereta.action.STOP_ACTIVE_TRIP"
        const val ACTION_REFRESH = "id.temankereta.teman_kereta.action.REFRESH_ACTIVE_TRIP_LOCATION"

        private const val NOTIFICATION_CHANNEL_ID = "active_trip_location"
        private const val NOTIFICATION_ID = 41_002
        private const val OPEN_REQUEST_CODE = 41_003
        private const val STOP_REQUEST_CODE = 41_004

        // Fixed, not adaptive: the same interval regardless of speed/idle
        // time. `lowBatteryMode` is the one deliberate, user-chosen escape
        // hatch to the slower balanced-power preset below.
        private const val HIGH_ACCURACY_INTERVAL_MS = 3_000L
        private const val HIGH_ACCURACY_MIN_INTERVAL_MS = 2_000L
        private const val LOW_BATTERY_INTERVAL_MS = 12_000L
        private const val LOW_BATTERY_MIN_INTERVAL_MS = 8_000L

        private const val ACCURACY_CEILING_METERS = 75f
        private const val JITTER_FLOOR_METERS = 5f
        // ~55 m/s (~200 km/h) — generous headroom above any KRL/MRT/LRT
        // service speed, just there to reject GPS-jump artifacts.
        private const val IMPLAUSIBLE_SPEED_METERS_PER_SECOND = 55.0
        // Below a fast walking pace — a reported speed under this is
        // indistinguishable from stationary/float noise (see the comment at
        // its use site), so the derived-from-distance fallback takes over.
        const val MIN_USABLE_REPORTED_SPEED_MPS = 0.3f

        // Watchdog. The interval is what it costs when everything is fine
        // (one SharedPreferences read); the threshold is how long a real
        // tunnel/dead-zone is allowed to look like normal operation before
        // the subscription gets rebuilt. HIGH_ACCURACY_INTERVAL_MS is 3s, so
        // 90s of total silence is far outside anything healthy.
        private const val WATCHDOG_INTERVAL_MS = 30_000L
        private const val STALE_FIX_THRESHOLD_MS = 90_000L
        private const val SINGLE_FIX_MAX_AGE_MS = 10_000L
        private const val SINGLE_FIX_TIMEOUT_MS = 20_000L

        // What counts as "we lost you and you kept going": both a long
        // enough silence to be a real outage rather than a skipped sample,
        // and enough movement that the rider is plainly somewhere else.
        private const val SIGNAL_GAP_THRESHOLD_MS = 120_000L
        private const val SIGNAL_GAP_MIN_DISTANCE_METERS = 400.0

        fun start(context: Context) = dispatch(context, ACTION_START)

        fun update(context: Context) = dispatch(context, ACTION_UPDATE)

        /** Backs the rider-facing "Perbarui lokasi" button (see `ActiveTripController.refreshLocation`). */
        fun refresh(context: Context) = dispatch(context, ACTION_REFRESH)

        fun stop(context: Context) {
            val intent = Intent(context, ActiveTripLocationService::class.java).apply { action = ACTION_STOP }
            try {
                context.startService(intent)
            } catch (_: IllegalStateException) {
                context.stopService(intent)
            }
        }

        private fun dispatch(context: Context, actionName: String) {
            val intent = Intent(context, ActiveTripLocationService::class.java).apply { action = actionName }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}

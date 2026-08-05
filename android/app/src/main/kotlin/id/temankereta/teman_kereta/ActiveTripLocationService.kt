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
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

class ActiveTripLocationService : Service(), LocationListener {
    private lateinit var locationManager: LocationManager
    private lateinit var notificationManager: NotificationManager
    private var currentSamplingProfile: SamplingProfile? = null
    private var lastProfileChangeAt = 0L
    private var explicitlyStopped = false

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
    }

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

        requestLocationUpdates(selectSamplingProfile(speedMetersPerSecond = null))
        return START_STICKY
    }

    override fun onLocationChanged(location: Location) {
        NativeStateStore.preferences(this).edit()
            .putLong(
                NativeStateStore.ACTIVE_LOCATION_LATITUDE,
                java.lang.Double.doubleToRawLongBits(location.latitude),
            )
            .putLong(
                NativeStateStore.ACTIVE_LOCATION_LONGITUDE,
                java.lang.Double.doubleToRawLongBits(location.longitude),
            )
            .putFloat(NativeStateStore.ACTIVE_LOCATION_ACCURACY, location.accuracy)
            .putFloat(
                NativeStateStore.ACTIVE_LOCATION_SPEED,
                if (location.hasSpeed()) location.speed.coerceAtLeast(0f) else 0f,
            )
            .putLong(NativeStateStore.ACTIVE_LOCATION_AT, location.time)
            .putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "tracking")
            .apply()

        val desiredProfile = selectSamplingProfile(
            speedMetersPerSecond = if (location.hasSpeed()) location.speed else null,
        )
        val now = System.currentTimeMillis()
        if (desiredProfile != currentSamplingProfile && now - lastProfileChangeAt >= PROFILE_CHANGE_DEBOUNCE_MS) {
            requestLocationUpdates(desiredProfile)
        }
    }

    @Deprecated("Deprecated by Android; retained for API 24 LocationListener compatibility")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    override fun onProviderEnabled(provider: String) {
        requestLocationUpdates(selectSamplingProfile(speedMetersPerSecond = null))
    }

    override fun onProviderDisabled(provider: String) {
        val anyProviderEnabled = enabledProviders().isNotEmpty()
        if (!anyProviderEnabled) {
            NativeStateStore.preferences(this).edit()
                .putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "location_provider_disabled")
                .apply()
        }
    }

    override fun onDestroy() {
        locationManager.removeUpdates(this)
        currentSamplingProfile = null
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
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
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
            nextStation.isNotBlank() -> getString(
                R.string.active_trip_notification_next,
                nextStation,
                remaining,
            )
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

        val stopIntent = Intent(this, ActiveTripLocationService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            STOP_REQUEST_CODE,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val publicVersion = newNotificationBuilder()
            .setSmallIcon(R.drawable.ic_stat_train)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(getString(R.string.active_trip_notification_generic))
            .build()

        val builder = newNotificationBuilder()
            .setSmallIcon(R.drawable.ic_stat_train)
            .setContentTitle(title)
            .setContentText(content)
            .setContentIntent(openPendingIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .addAction(
                Notification.Action.Builder(
                    null,
                    getString(R.string.active_trip_notification_stop),
                    stopPendingIntent,
                ).build(),
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

    private fun requestLocationUpdates(profile: SamplingProfile) {
        if (!hasForegroundLocationPermission()) return
        try {
            locationManager.removeUpdates(this)
            val providers = enabledProviders()
            for (provider in providers) {
                locationManager.requestLocationUpdates(
                    provider,
                    profile.intervalMs,
                    profile.minDistanceMeters,
                    this,
                    Looper.getMainLooper(),
                )
            }
            currentSamplingProfile = profile
            lastProfileChangeAt = System.currentTimeMillis()
            NativeStateStore.preferences(this).edit()
                .putString(
                    NativeStateStore.ACTIVE_LOCATION_STATUS,
                    if (providers.isEmpty()) "location_provider_disabled" else "waiting_for_location",
                )
                .apply()
        } catch (_: SecurityException) {
            NativeStateStore.preferences(this).edit()
                .putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "permission_missing")
                .apply()
            stopSelf()
        } catch (_: IllegalArgumentException) {
            NativeStateStore.preferences(this).edit()
                .putString(NativeStateStore.ACTIVE_LOCATION_STATUS, "location_provider_unavailable")
                .apply()
        }
    }

    private fun enabledProviders(): List<String> {
        val providers = mutableListOf<String>()
        val hasFine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (hasFine && isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            providers += LocationManager.GPS_PROVIDER
        }
        if (isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            providers += LocationManager.NETWORK_PROVIDER
        }
        return providers
    }

    private fun isProviderEnabled(provider: String): Boolean = try {
        locationManager.isProviderEnabled(provider)
    } catch (_: Exception) {
        false
    }

    private fun selectSamplingProfile(speedMetersPerSecond: Float?): SamplingProfile {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return when {
            powerManager.isPowerSaveMode -> SamplingProfile.POWER_SAVER
            speedMetersPerSecond == null -> SamplingProfile.BALANCED
            speedMetersPerSecond < STATIONARY_SPEED_METERS_PER_SECOND -> SamplingProfile.STATIONARY
            else -> SamplingProfile.MOVING
        }
    }

    private fun hasForegroundLocationPermission(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun stopActiveTrip() {
        explicitlyStopped = true
        locationManager.removeUpdates(this)
        NativeStateStore.clearActiveTrip(this)
        TemanKeretaWidgetUpdater.updateActiveTrip(this)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private enum class SamplingProfile(
        val intervalMs: Long,
        val minDistanceMeters: Float,
    ) {
        MOVING(8_000L, 15f),
        BALANCED(15_000L, 25f),
        STATIONARY(30_000L, 50f),
        POWER_SAVER(45_000L, 75f),
    }

    companion object {
        const val ACTION_START = "id.temankereta.teman_kereta.action.START_ACTIVE_TRIP"
        const val ACTION_UPDATE = "id.temankereta.teman_kereta.action.UPDATE_ACTIVE_TRIP"
        const val ACTION_STOP = "id.temankereta.teman_kereta.action.STOP_ACTIVE_TRIP"

        private const val NOTIFICATION_CHANNEL_ID = "active_trip_location"
        private const val NOTIFICATION_ID = 41_002
        private const val OPEN_REQUEST_CODE = 41_003
        private const val STOP_REQUEST_CODE = 41_004
        private const val PROFILE_CHANGE_DEBOUNCE_MS = 30_000L
        private const val STATIONARY_SPEED_METERS_PER_SECOND = 1.0f

        fun start(context: Context) {
            dispatch(context, ACTION_START)
        }

        fun update(context: Context) {
            dispatch(context, ACTION_UPDATE)
        }

        fun stop(context: Context) {
            val intent = Intent(context, ActiveTripLocationService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (_: IllegalStateException) {
                // The activity bridge also clears state, so a service already evicted by Android
                // needs no background restart solely to process a stop request.
                context.stopService(intent)
            }
        }

        private fun dispatch(context: Context, actionName: String) {
            val intent = Intent(context, ActiveTripLocationService::class.java).apply {
                action = actionName
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}

package id.temankereta.teman_kereta

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

/**
 * Google Play services clears every geofence registration on device reboot (a plain app
 * process kill/restart is fine — registrations survive that). This replays the exact
 * last-registered scope — whichever Dart-side feature (an active trip's route or
 * ride-detection's saved stations) owned it — straight from persisted native state,
 * without needing to relaunch the Flutter engine.
 */
class GeofenceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = NativeStateStore.preferences(context)
        val expiresAt = if (prefs.contains(NativeStateStore.GEOFENCE_EXPIRES_AT)) {
            prefs.getLong(NativeStateStore.GEOFENCE_EXPIRES_AT, 0L)
        } else {
            null
        }
        val now = System.currentTimeMillis()
        if (expiresAt == null || expiresAt <= now) {
            NativeStateStore.recordGeofenceBootRecovery(context, "skipped_no_active_scope")
            return
        }

        val details = NativeStateStore.geofenceDetails(context)
        if (details.isEmpty()) {
            NativeStateStore.recordGeofenceBootRecovery(context, "skipped_no_details")
            return
        }

        if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            NativeStateStore.recordGeofenceBootRecovery(context, "skipped_missing_fine_location")
            return
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            context.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            NativeStateStore.recordGeofenceBootRecovery(context, "skipped_missing_background_location")
            return
        }

        val geofences = details.map { detail ->
            Geofence.Builder()
                .setRequestId("$REQUEST_ID_PREFIX${detail.id}")
                .setCircularRegion(detail.latitude, detail.longitude, detail.radiusMeters)
                .setExpirationDuration(expiresAt - now)
                .setTransitionTypes(
                    Geofence.GEOFENCE_TRANSITION_ENTER or
                        Geofence.GEOFENCE_TRANSITION_EXIT or
                        Geofence.GEOFENCE_TRANSITION_DWELL,
                )
                .setLoiteringDelay(DWELL_LOITERING_DELAY_MS)
                .build()
        }
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofences)
            .build()

        // addGeofences() is async, and a plain BroadcastReceiver's process has no
        // guarantee of staying alive past onReceive() returning — goAsync() extends
        // that lifetime until finish() is called, so the completion listener below
        // (and its NativeStateStore write) isn't racing against process death.
        val pendingResult = goAsync()
        try {
            LocationServices.getGeofencingClient(context)
                .addGeofences(request, StationGeofenceReceiver.pendingIntent(context))
                .addOnCompleteListener { task ->
                    NativeStateStore.recordGeofenceBootRecovery(
                        context,
                        if (task.isSuccessful) "success" else "failed_${task.exception?.javaClass?.simpleName}",
                    )
                    pendingResult.finish()
                }
        } catch (error: SecurityException) {
            // Permission was revoked between the checks above and this call; nothing to recover
            // from a BroadcastReceiver with no UI to fall back on.
            NativeStateStore.recordGeofenceBootRecovery(context, "failed_SecurityException")
            pendingResult.finish()
        }
    }

    companion object {
        private const val REQUEST_ID_PREFIX = "station:"
        private const val DWELL_LOITERING_DELAY_MS = 90_000
    }
}

package id.temankereta.teman_kereta

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class StationGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_STATION_GEOFENCE_EVENT) return
        val event = GeofencingEvent.fromIntent(intent) ?: return
        val editor = NativeStateStore.preferences(context).edit()

        if (event.hasError()) {
            editor
                .putString(NativeStateStore.GEOFENCE_LAST_ERROR, "status:${event.errorCode}")
                .putLong(NativeStateStore.GEOFENCE_LAST_AT, System.currentTimeMillis())
                .apply()
            return
        }

        val transition = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "enter"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "exit"
            Geofence.GEOFENCE_TRANSITION_DWELL -> "dwell"
            else -> "unknown"
        }
        val stationIds = event.triggeringGeofences.orEmpty()
            .map { it.requestId.removePrefix(REQUEST_ID_PREFIX) }
            .filter(String::isNotBlank)
            .toSet()

        editor
            .putStringSet(NativeStateStore.GEOFENCE_LAST_IDS, stationIds)
            .putString(NativeStateStore.GEOFENCE_LAST_TRANSITION, transition)
            .putLong(NativeStateStore.GEOFENCE_LAST_AT, System.currentTimeMillis())
            .remove(NativeStateStore.GEOFENCE_LAST_ERROR)
            .apply()
    }

    companion object {
        const val ACTION_STATION_GEOFENCE_EVENT =
            "id.temankereta.teman_kereta.action.STATION_GEOFENCE_EVENT"
        private const val REQUEST_ID_PREFIX = "station:"
        private const val PENDING_INTENT_REQUEST_CODE = 52_001

        // Shared by StationGeofenceManager (register/unregister from the Flutter side) and
        // GeofenceBootReceiver (replaying the last scope after a reboot) so both target the
        // exact same registered PendingIntent that Play Services matches transitions against.
        fun pendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, StationGeofenceReceiver::class.java).apply {
                action = ACTION_STATION_GEOFENCE_EVENT
            }
            val mutabilityFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            return PendingIntent.getBroadcast(
                context,
                PENDING_INTENT_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or mutabilityFlag,
            )
        }
    }
}

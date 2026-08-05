package id.temankereta.teman_kereta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
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
    }
}

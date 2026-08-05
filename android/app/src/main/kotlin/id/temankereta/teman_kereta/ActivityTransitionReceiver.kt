package id.temankereta.teman_kereta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity

/**
 * Receives Activity Recognition Transition API events. Unlike the polling
 * `ActivityRecognitionClient.requestActivityUpdates` API, transitions only
 * fire when Google Play services itself is confident enough that the
 * activity changed, so there is no separate per-event confidence number to
 * record here — the event firing at all *is* the signal.
 */
class ActivityTransitionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ACTIVITY_TRANSITION_EVENT) return
        if (!ActivityTransitionResult.hasResult(intent)) return
        val result = ActivityTransitionResult.extractResult(intent) ?: return
        val latest = result.transitionEvents.maxByOrNull { it.elapsedRealTimeNanos } ?: return

        val type = when (latest.activityType) {
            DetectedActivity.IN_VEHICLE -> "in_vehicle"
            DetectedActivity.ON_FOOT, DetectedActivity.WALKING, DetectedActivity.RUNNING -> "on_foot"
            DetectedActivity.STILL -> "still"
            else -> "unknown"
        }

        NativeStateStore.preferences(context).edit()
            .putString(NativeStateStore.ACTIVITY_LAST_TYPE, type)
            .putInt(NativeStateStore.ACTIVITY_LAST_CONFIDENCE, 100)
            .putLong(NativeStateStore.ACTIVITY_LAST_AT, System.currentTimeMillis())
            .apply()
    }

    companion object {
        const val ACTION_ACTIVITY_TRANSITION_EVENT =
            "id.temankereta.teman_kereta.action.ACTIVITY_TRANSITION_EVENT"
    }
}

package id.temankereta.teman_kereta

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.location.ActivityRecognitionClient
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.DetectedActivity
import io.flutter.plugin.common.MethodChannel

/**
 * Wraps the Activity Recognition Transition API for TK's ride-detection
 * confidence engine (PRD §9). Only IN_VEHICLE/ON_FOOT/STILL enter
 * transitions are monitored — the minimum needed to tell the confidence
 * engine "the user is plausibly on a train" apart from "still walking or
 * stationary" — matching the low-power, event-driven approach PRD §31
 * requires instead of continuous polling.
 */
internal class ActivityRecognitionManager(private val activity: Activity) {
    private val client: ActivityRecognitionClient =
        com.google.android.gms.location.ActivityRecognition.getClient(activity)

    fun hasPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            activity.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED

    fun startTransitionUpdates(result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error(
                "MISSING_PERMISSION",
                "Izin pengenalan aktivitas belum diberikan.",
                mapOf("permissions" to listOf(Manifest.permission.ACTIVITY_RECOGNITION)),
            )
            return
        }

        val request = ActivityTransitionRequest(monitoredTransitions())
        try {
            client.requestActivityTransitionUpdates(request, pendingIntent())
                .addOnSuccessListener { result.success(mapOf("started" to true)) }
                .addOnFailureListener { error ->
                    result.error(
                        "ACTIVITY_RECOGNITION_FAILED",
                        error.message ?: "Google Play services menolak permintaan pengenalan aktivitas.",
                        null,
                    )
                }
        } catch (error: SecurityException) {
            result.error(
                "MISSING_PERMISSION",
                "Izin pengenalan aktivitas berubah saat didaftarkan.",
                error.message,
            )
        }
    }

    fun stopTransitionUpdates(result: MethodChannel.Result) {
        try {
            client.removeActivityTransitionUpdates(pendingIntent())
                .addOnSuccessListener { result.success(mapOf("stopped" to true)) }
                .addOnFailureListener { error ->
                    result.error("ACTIVITY_RECOGNITION_FAILED", error.message, null)
                }
        } catch (error: SecurityException) {
            result.error("MISSING_PERMISSION", error.message, null)
        }
    }

    private fun monitoredTransitions(): List<ActivityTransition> =
        listOf(DetectedActivity.IN_VEHICLE, DetectedActivity.ON_FOOT, DetectedActivity.STILL).map { type ->
            ActivityTransition.Builder()
                .setActivityType(type)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                .build()
        }

    private fun pendingIntent(): PendingIntent {
        val intent = Intent(activity, ActivityTransitionReceiver::class.java).apply {
            action = ActivityTransitionReceiver.ACTION_ACTIVITY_TRANSITION_EVENT
        }
        val mutabilityFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        return PendingIntent.getBroadcast(
            activity,
            ACTIVITY_PENDING_INTENT_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or mutabilityFlag,
        )
    }

    companion object {
        private const val ACTIVITY_PENDING_INTENT_REQUEST_CODE = 52_101
    }
}

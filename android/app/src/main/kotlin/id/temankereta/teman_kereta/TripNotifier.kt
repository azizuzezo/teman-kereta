package id.temankereta.teman_kereta

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.speech.tts.TextToSpeech
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Locale

/**
 * Native counterpart of `LocalNotificationService` (Dart) — posts the same
 * stop/transfer/missed-destination alerts, with the same channel ids, ids,
 * and copy, but callable from [ActiveTripLocationService] with zero
 * dependency on the Flutter engine being alive (see the plan doc for why:
 * this app has no headless Dart execution, so progression detected while
 * the app is swiped away has to announce itself from here).
 *
 * Channels are created here too (idempotent — Android ignores a repeat
 * `createNotificationChannel` call with the same id), since this service can
 * be the very first thing to ever notify on a given channel if the app was
 * swiped away before Dart's `LocalNotificationService.initialize()` ever ran
 * for this install.
 */
internal class TripNotifier(context: Context) {
    private val appContext = context.applicationContext
    private val notificationManager =
        appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    init {
        createChannels()
        tts = TextToSpeech(appContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.language = Locale.forLanguageTag("id-ID")
            }
        }
    }

    fun shutdown() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        ttsReady = false
    }

    fun showStopAlert(remainingStops: Int, destination: String, vibrate: Boolean, sound: Boolean) {
        val title = if (remainingStops == 0) "Tujuan telah tiba" else "$remainingStops stasiun lagi"
        val body = if (remainingStops == 0) {
            "Periksa kondisi sekitar sebelum turun di $destination."
        } else {
            "Bersiap menuju $destination."
        }
        val spokenText = if (remainingStops == 0) {
            "Hampir sampai tujuan, $destination."
        } else {
            "$remainingStops stasiun lagi menuju $destination."
        }
        val customSound = when {
            remainingStops == 0 -> "arrive_station"
            remainingStops in 1..3 -> "remaining_station_$remainingStops"
            else -> null
        }
        post(
            id = 4100 + remainingStops,
            channelId = if (customSound == null) "trip_alerts" else "trip_alert_$customSound",
            title = title,
            body = body,
            vibrate = vibrate,
            sound = sound,
            spokenText = spokenText,
        )
    }

    fun showTransferApproachingAlert(remainingStops: Int, stationName: String, vibrate: Boolean, sound: Boolean) {
        val customSound = if (remainingStops in 1..3) "remaining_transit_$remainingStops" else null
        post(
            id = 4150 + remainingStops,
            channelId = if (customSound == null) "trip_alerts" else "trip_alert_$customSound",
            title = "$remainingStops stasiun lagi menuju transit",
            body = "Bersiap transit di $stationName.",
            vibrate = vibrate,
            sound = sound,
            spokenText = "$remainingStops stasiun lagi menuju transit di $stationName.",
        )
    }

    fun showTransferAlert(stationName: String, instruction: String?, vibrate: Boolean, sound: Boolean) {
        post(
            id = 4200,
            channelId = "trip_alert_transit_reminder",
            title = "Saatnya transit di $stationName",
            body = instruction ?: "Turun di $stationName dan lanjutkan ke kereta berikutnya.",
            vibrate = vibrate,
            sound = sound,
            spokenText = "Saatnya transit di $stationName.",
        )
    }

    /**
     * Arrival at the trip's destination — the trip auto-finishes at this
     * point (see `ActiveTripController`), so this is the rider's summary,
     * not a "get ready" warning. Fired from here rather than Dart because
     * arrival is decided natively and must announce itself even when the
     * Flutter engine is gone.
     */
    fun showArrivalAlert(
        destination: String,
        durationMillis: Long,
        distanceMeters: Double,
        vibrate: Boolean,
        sound: Boolean,
    ) {
        val recap = TripRecap.of(durationMillis, distanceMeters)
        post(
            id = 4100,
            channelId = "trip_alert_arrive_station",
            title = "Selamat, kamu tiba di $destination",
            body = recap.summaryLine,
            vibrate = vibrate,
            sound = sound,
            spokenText = "Selamat, kamu sudah tiba di $destination.",
        )
    }

    fun showMissedDestinationAlert(destination: String, vibrate: Boolean, sound: Boolean) {
        post(
            id = 4300,
            channelId = "trip_alert_alert_terlewat",
            title = "Sepertinya kamu melewati $destination",
            body = "Buka aplikasi untuk mencari rute kembali ke $destination.",
            vibrate = vibrate,
            sound = sound,
            spokenText = null,
        )
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        createChannel("trip_alerts", "Peringatan perjalanan", null)
        createChannel("trip_alert_arrive_station", "Tiba di tujuan", "arrive_station")
        for (n in 1..3) {
            createChannel("trip_alert_remaining_station_$n", "$n stasiun sebelum tujuan", "remaining_station_$n")
            createChannel("trip_alert_remaining_transit_$n", "$n stasiun sebelum transit", "remaining_transit_$n")
        }
        createChannel("trip_alert_transit_reminder", "Tiba di stasiun transit", "transit_reminder")
        createChannel("trip_alert_alert_terlewat", "Tujuan terlewat", "alert_terlewat")
    }

    private fun createChannel(id: String, name: String, soundResource: String?) {
        val channel = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Peringatan stasiun tujuan dan transit"
            enableVibration(true)
        }
        if (soundResource != null) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            channel.setSound(Uri.parse("android.resource://${appContext.packageName}/raw/$soundResource"), attributes)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun post(
        id: Int,
        channelId: String,
        title: String,
        body: String,
        vibrate: Boolean,
        sound: Boolean,
        spokenText: String?,
    ) {
        val openIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("temankereta://app/active-trip"),
            appContext,
            MainActivity::class.java,
        ).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            appContext,
            id,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(appContext, channelId)
            .setSmallIcon(R.drawable.ic_stat_tk)
            .setLargeIcon(BitmapFactory.decodeResource(appContext.resources, R.mipmap.ic_launcher))
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
        if (!vibrate) {
            builder.setVibrate(longArrayOf(0))
        }
        try {
            NotificationManagerCompat.from(appContext).notify(id, builder.build())
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS revoked mid-trip — never crash tracking for it.
        }
        if (sound && spokenText != null && ttsReady) {
            tts?.speak(spokenText, TextToSpeech.QUEUE_ADD, null, "trip_alert_$id")
        }
    }
}

package id.temankereta.teman_kereta

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
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
        // Deliberately not stopping AlertAudioPlayer: the arrival alert is
        // posted just before the trip finishes and this service stops, and
        // the announcement has to be heard to its last word. The player
        // owns its own lifetime and ends itself.
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
        val voice = when {
            remainingStops == 0 -> "arrive_station"
            remainingStops in 1..3 -> "remaining_station_$remainingStops"
            else -> null
        }
        post(
            id = 4100 + remainingStops,
            title = title,
            body = body,
            vibrate = vibrate,
            sound = sound,
            voice = voice,
            spokenText = spokenText,
            bell = remainingStops == 1,
        )
    }

    fun showTransferApproachingAlert(remainingStops: Int, stationName: String, vibrate: Boolean, sound: Boolean) {
        val voice = if (remainingStops in 1..3) "remaining_transit_$remainingStops" else null
        post(
            id = 4150 + remainingStops,
            title = "$remainingStops stasiun lagi menuju transit",
            body = "Bersiap transit di $stationName.",
            vibrate = vibrate,
            sound = sound,
            voice = voice,
            spokenText = "$remainingStops stasiun lagi menuju transit di $stationName.",
            bell = remainingStops == 1,
        )
    }

    fun showTransferAlert(stationName: String, instruction: String?, vibrate: Boolean, sound: Boolean) {
        post(
            id = 4200,
            title = "Saatnya transit di $stationName",
            body = instruction ?: "Turun di $stationName dan lanjutkan ke kereta berikutnya.",
            vibrate = vibrate,
            sound = sound,
            voice = "transit_reminder",
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
            title = "Selamat, kamu tiba di $destination",
            body = recap.summaryLine,
            vibrate = vibrate,
            sound = sound,
            voice = "arrive_station",
            spokenText = "Selamat, kamu sudah tiba di $destination.",
        )
    }

    fun showMissedDestinationAlert(destination: String, vibrate: Boolean, sound: Boolean) {
        post(
            id = 4300,
            title = "Sepertinya kamu melewati $destination",
            body = "Buka aplikasi untuk mencari rute kembali ke $destination.",
            vibrate = vibrate,
            sound = sound,
            voice = "terlewat",
            spokenText = null,
        )
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        // Channels that carried the recorded voice line as their own sound
        // are retired (a channel's sound cannot be changed after creation):
        // the voice is played by AlertAudioPlayer now, so the channels below
        // are silent, heads-up and vibrate only.
        for (old in RETIRED_CHANNEL_IDS) notificationManager.deleteNotificationChannel(old)
        createChannel(GENERIC_CHANNEL_ID, "Peringatan perjalanan", withSound = true)
        createChannel(channelIdFor("arrive_station"), "Tiba di tujuan", withSound = false)
        for (n in 1..3) {
            createChannel(channelIdFor("remaining_station_$n"), "$n stasiun sebelum tujuan", withSound = false)
            createChannel(channelIdFor("remaining_transit_$n"), "$n stasiun sebelum transit", withSound = false)
        }
        createChannel(channelIdFor("transit_reminder"), "Tiba di stasiun transit", withSound = false)
        createChannel(channelIdFor("terlewat"), "Tujuan terlewat", withSound = false)
    }

    private fun createChannel(id: String, name: String, withSound: Boolean) {
        val channel = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Peringatan stasiun tujuan dan transit"
            enableVibration(true)
            if (!withSound) setSound(null, null)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun post(
        id: Int,
        title: String,
        body: String,
        vibrate: Boolean,
        sound: Boolean,
        voice: String?,
        spokenText: String?,
        bell: Boolean = false,
    ) {
        val channelId = if (voice == null) GENERIC_CHANNEL_ID else channelIdFor(voice)
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
        // An alert with a recorded voice line (res/raw wav) is played here:
        // voice, then (for "1 stasiun lagi") the bell, each started by the
        // previous one's completion callback and routed to the headset when
        // one is connected. The system TTS is only the fallback for the
        // generic channel that has no recording.
        if (sound && voice != null) {
            AlertAudioPlayer.play(appContext, voice, bell)
        } else if (sound && spokenText != null && ttsReady) {
            tts?.speak(spokenText, TextToSpeech.QUEUE_ADD, null, "trip_alert_$id")
        }
    }

    private companion object {
        const val GENERIC_CHANNEL_ID = "trip_alerts"

        /** Must match `alertChannelId` in `lib/core/notifications/alert_audio_plan.dart`. */
        fun channelIdFor(voice: String) = "tk_alert_$voice"

        val RETIRED_CHANNEL_IDS = listOf(
            "trip_alert_arrive_station",
            "trip_alert_remaining_station_1",
            "trip_alert_remaining_station_2",
            "trip_alert_remaining_station_3",
            "trip_alert_remaining_transit_1",
            "trip_alert_remaining_transit_2",
            "trip_alert_remaining_transit_3",
            "trip_alert_transit_reminder",
            "trip_alert_terlewat",
            "trip_alert_alert_terlewat",
        )
    }
}

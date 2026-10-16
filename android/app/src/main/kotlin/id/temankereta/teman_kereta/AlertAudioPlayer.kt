package id.temankereta.teman_kereta

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log

/**
 * Plays the trip announcements: the recorded voice line (res/raw wav) and,
 * for "1 stasiun lagi", the bell (`assets/alarm.mp3`) straight after it.
 *
 * Why this exists instead of a notification channel sound plus a timer:
 * the channel sound is played asynchronously by the system, so the app can
 * neither know when it actually starts nor when it ends. The old bell was
 * scheduled at `notify() + <wav length>`; the sound starts some time after
 * `notify()` (binder hop, notification enqueue, ringtone player prepare), so
 * the loud bell began while the voice line still had its last words to say.
 * Here both clips are played by this class, in sequence, each one started by
 * the previous one's real `OnCompletionListener`. A system sound also cannot
 * be sent to the headset only, which is the second reason it is gone (the
 * alert channels are silent now, see [TripNotifier]).
 *
 * Everything runs on the main looper. One session at a time: a new alert
 * replaces whatever is still sounding.
 */
internal object AlertAudioPlayer {
    private val handler = Handler(Looper.getMainLooper())
    private var session: Session? = null

    /**
     * Speaks [voiceResource] (a `res/raw` name such as `remaining_station_1`)
     * and then, when [bell] is set, sounds the bell. Either part may be
     * absent. Safe to call from any thread.
     */
    fun play(context: Context, voiceResource: String?, bell: Boolean) {
        val appContext = context.applicationContext
        val clips = mutableListOf<Clip>()
        if (voiceResource != null) clips.add(Clip.Voice(voiceResource))
        if (bell) clips.add(Clip.Bell)
        if (clips.isEmpty()) return
        handler.post {
            session?.finish()
            val next = Session(appContext, handler, clips) { done ->
                if (session === done) session = null
            }
            session = next
            next.start()
        }
    }

    /**
     * The rider noticed the alert (opened the app, tapped "Matikan alarm"):
     * silence the bell, whether it is playing or still queued behind the
     * voice line, but let the announcement finish.
     */
    fun silenceBell() {
        handler.post { session?.silenceBell() }
    }

    /** Stops everything, now. */
    fun stop() {
        handler.post { session?.finish() }
    }

    /** Current output route, for Dart. Safe from any thread. */
    fun routeSnapshot(context: Context): Map<String, Any?> = AudioRouting.snapshot(context.applicationContext)
}

/** Reads the connected output devices. */
internal object AudioRouting {
    fun findHeadset(audioManager: AudioManager): AudioDeviceInfo? {
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
        val index = AudioRoutePolicy.pickBestHeadsetIndex(devices.map { it.type }) ?: return null
        return devices[index]
    }

    fun snapshot(context: Context): Map<String, Any?> {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val headset = try {
            findHeadset(audioManager)
        } catch (_: Exception) {
            null
        }
        return mapOf(
            "route" to if (headset != null) "headset" else "speaker",
            "deviceKind" to headset?.let { AudioRoutePolicy.kindLabel(it.type) },
            "deviceName" to headset?.productName?.toString(),
        )
    }
}

private sealed class Clip {
    class Voice(val resource: String) : Clip()
    object Bell : Clip()
}

/**
 * One alert's audio: focus, route, volume and the clip sequence. All methods
 * must be called on the main looper.
 */
private class Session(
    private val context: Context,
    private val handler: Handler,
    private val clips: MutableList<Clip>,
    private val onFinished: (Session) -> Unit,
) {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private var index = -1
    private var player: MediaPlayer? = null
    private var clipToken = 0
    private var timeoutTask: Runnable? = null
    private var finished = false

    /** Id of the headset the current clip is routed to, null when it plays on the speaker. */
    private var activeHeadsetId: Int? = null

    private val focusListener = AudioManager.OnAudioFocusChangeListener { }
    private var focusRequest: AudioFocusRequest? = null
    private var deviceCallback: AudioDeviceCallback? = null

    private var boostedStream = NO_STREAM
    private var savedVolume = 0
    private var boostedVolume = 0

    fun start() {
        requestFocus()
        registerDeviceCallback()
        playClip(0)
    }

    fun silenceBell() {
        if (finished) return
        if (clips.getOrNull(index) is Clip.Bell) {
            finish()
            return
        }
        clips.removeAll { it is Clip.Bell }
    }

    fun finish() {
        if (finished) return
        finished = true
        clipToken++
        cancelTimeout()
        releasePlayer()
        unregisterDeviceCallback()
        restoreVolume()
        abandonFocus()
        onFinished(this)
    }

    // ---- sequencing -------------------------------------------------------

    private fun playClip(position: Int) {
        if (finished) return
        cancelTimeout()
        releasePlayer()
        if (position >= clips.size) {
            finish()
            return
        }
        index = position
        val clip = clips[position]

        // Route is decided here, per clip, not once per alert: the headset
        // may have been (un)plugged since the previous clip started.
        val headset = findHeadsetOrNull()
        activeHeadsetId = headset?.id
        applyVolume(headset != null)

        val descriptor = try {
            openClip(clip)
        } catch (error: Exception) {
            Log.w(TAG, "cannot open $clip: ${error.message}")
            null
        }
        if (descriptor == null) {
            playClip(position + 1)
            return
        }

        val token = ++clipToken
        val mp = MediaPlayer()
        player = mp
        try {
            mp.setAudioAttributes(attributesFor(clip, headset != null))
            if (headset != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // Below API 28 USAGE_MEDIA already goes to the connected
                // headset and never to the speaker, so nothing more is needed.
                mp.setPreferredDevice(headset)
            }
            try {
                mp.setWakeMode(context, PowerManager.PARTIAL_WAKE_LOCK)
            } catch (_: Exception) {
                // Best effort: without it a screen-off device may sleep mid-clip.
            }
            descriptor.use { fd -> mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length) }
            mp.setOnPreparedListener { prepared ->
                if (token == clipToken && !finished) {
                    // The real length plus a margin: a missing completion
                    // callback can delay the next step, never block it.
                    armTimeout(token, prepared.duration.coerceAtLeast(0) + PLAYBACK_MARGIN_MS)
                    prepared.start()
                }
            }
            mp.setOnCompletionListener {
                if (token == clipToken && !finished) playClip(index + 1)
            }
            mp.setOnErrorListener { _, what, extra ->
                Log.w(TAG, "player error what=$what extra=$extra on $clip")
                if (token == clipToken && !finished) playClip(index + 1)
                true
            }
            armTimeout(token, PREPARE_TIMEOUT_MS)
            mp.prepareAsync()
            Log.i(TAG, "clip=$index/${clips.size} route=${if (headset != null) "headset:${headset.productName}" else "speaker"}")
        } catch (error: Exception) {
            Log.w(TAG, "cannot start $clip: ${error.message}")
            releasePlayer()
            playClip(position + 1)
        }
    }

    private fun armTimeout(token: Int, delayMillis: Long) {
        cancelTimeout()
        val task = Runnable {
            if (token == clipToken && !finished) {
                Log.w(TAG, "clip $index timed out, moving on")
                playClip(index + 1)
            }
        }
        timeoutTask = task
        handler.postDelayed(task, delayMillis)
    }

    private fun cancelTimeout() {
        timeoutTask?.let(handler::removeCallbacks)
        timeoutTask = null
    }

    private fun releasePlayer() {
        val current = player ?: return
        player = null
        try {
            current.setOnPreparedListener(null)
            current.setOnCompletionListener(null)
            current.setOnErrorListener(null)
        } catch (_: Exception) {
        }
        try {
            current.stop()
        } catch (_: IllegalStateException) {
        }
        try {
            current.release()
        } catch (_: Exception) {
        }
    }

    private fun openClip(clip: Clip): AssetFileDescriptor? = when (clip) {
        is Clip.Bell -> context.assets.openFd(BELL_ASSET)
        is Clip.Voice -> {
            val id = context.resources.getIdentifier(clip.resource, "raw", context.packageName)
            if (id == 0) null else context.resources.openRawResourceFd(id)
        }
    }

    private fun attributesFor(clip: Clip, headset: Boolean): AudioAttributes = when {
        // USAGE_MEDIA, never USAGE_ALARM: alarm-usage audio is forced onto
        // the speaker (and the headset too), which is the very bug.
        headset -> AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(
                if (clip is Clip.Voice) AudioAttributes.CONTENT_TYPE_SPEECH else AudioAttributes.CONTENT_TYPE_SONIFICATION,
            )
            .build()
        // Speaker: unchanged from before. The voice line used to be the
        // channel's USAGE_NOTIFICATION sound, the bell is an alarm.
        clip is Clip.Voice -> AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        else -> AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
    }

    private fun findHeadsetOrNull(): AudioDeviceInfo? = try {
        AudioRouting.findHeadset(audioManager)
    } catch (_: Exception) {
        null
    }

    // ---- headset disappearing mid-alert -----------------------------------

    private fun registerDeviceCallback() {
        val callback = object : AudioDeviceCallback() {
            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                val activeId = activeHeadsetId ?: return
                if (removedDevices?.any { it.id == activeId } == true) onHeadsetLost()
            }
        }
        try {
            audioManager.registerAudioDeviceCallback(callback, handler)
            deviceCallback = callback
        } catch (_: Exception) {
            deviceCallback = null
        }
    }

    private fun unregisterDeviceCallback() {
        val callback = deviceCallback ?: return
        deviceCallback = null
        try {
            audioManager.unregisterAudioDeviceCallback(callback)
        } catch (_: Exception) {
        }
    }

    /**
     * The headset the current clip was playing on is gone. If that clip is
     * the bell, the alert has already been delivered on the headset: stop,
     * and never replay it through the speaker. If it is still the voice
     * line, the alert is pending, so play it again from the start on what is
     * available now (speaker, or another headset).
     */
    private fun onHeadsetLost() {
        if (finished) return
        activeHeadsetId = null
        if (clips.getOrNull(index) is Clip.Bell) {
            Log.i(TAG, "headset lost during the bell, stopping")
            finish()
            return
        }
        Log.i(TAG, "headset lost during the announcement, replaying it on the speaker")
        playClip(index)
    }

    // ---- volume -----------------------------------------------------------

    /**
     * On a headset: raise STREAM_MUSIC to [AudioRoutePolicy.boostedVolumeIndex]
     * once per alert. Off a headset: put the rider's own level back if we had
     * raised it. The stream is the one the headset audio actually plays on
     * (USAGE_MEDIA); the speaker path keeps using its own alarm/notification
     * stream untouched.
     */
    private fun applyVolume(onHeadset: Boolean) {
        if (!onHeadset) {
            restoreVolume()
            return
        }
        if (boostedStream != NO_STREAM) return
        try {
            val stream = AudioManager.STREAM_MUSIC
            val current = audioManager.getStreamVolume(stream)
            val target = AudioRoutePolicy.boostedVolumeIndex(current, audioManager.getStreamMaxVolume(stream))
            if (target > current) {
                audioManager.setStreamVolume(stream, target, 0)
                boostedStream = stream
                savedVolume = current
                boostedVolume = target
                Log.i(TAG, "headset volume $current -> $target")
            }
        } catch (error: Exception) {
            Log.w(TAG, "cannot raise volume: ${error.message}")
        }
    }

    private fun restoreVolume() {
        val stream = boostedStream
        if (stream == NO_STREAM) return
        boostedStream = NO_STREAM
        try {
            // If the rider changed the volume while it was sounding, that
            // is their choice now: leave it.
            if (audioManager.getStreamVolume(stream) == boostedVolume) {
                audioManager.setStreamVolume(stream, savedVolume, 0)
            }
        } catch (error: Exception) {
            Log.w(TAG, "cannot restore volume: ${error.message}")
        }
    }

    // ---- audio focus ------------------------------------------------------

    /**
     * Transient focus for the whole sequence (voice and bell), released in
     * [finish]. The listener ignores focus loss on purpose: an arrival
     * announcement is short and safety-relevant, so it is not paused for
     * whatever grabbed focus next.
     */
    private fun requestFocus() {
        val onHeadset = findHeadsetOrNull() != null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val first = clips.firstOrNull() ?: return
                val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attributesFor(first, onHeadset))
                    .setOnAudioFocusChangeListener(focusListener, handler)
                    .build()
                focusRequest = request
                audioManager.requestAudioFocus(request)
            } else {
                requestLegacyFocus(onHeadset)
            }
        } catch (error: Exception) {
            Log.w(TAG, "cannot request audio focus: ${error.message}")
        }
    }

    @Suppress("DEPRECATION")
    private fun requestLegacyFocus(onHeadset: Boolean) {
        audioManager.requestAudioFocus(
            focusListener,
            if (onHeadset) AudioManager.STREAM_MUSIC else AudioManager.STREAM_ALARM,
            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
        )
    }

    private fun abandonFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            } else {
                abandonLegacyFocus()
            }
        } catch (_: Exception) {
        }
        focusRequest = null
    }

    @Suppress("DEPRECATION")
    private fun abandonLegacyFocus() {
        audioManager.abandonAudioFocus(focusListener)
    }

    private companion object {
        const val TAG = "TKAlertAudio"
        const val BELL_ASSET = "flutter_assets/assets/alarm.mp3"
        const val NO_STREAM = -1
        const val PREPARE_TIMEOUT_MS = 4_000L
        const val PLAYBACK_MARGIN_MS = 1_500L
    }
}

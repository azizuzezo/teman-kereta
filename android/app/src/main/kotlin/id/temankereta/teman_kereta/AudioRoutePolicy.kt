package id.temankereta.teman_kereta

/**
 * Pure decisions behind the alert audio routing: which output counts as a
 * headset, which of several connected ones to prefer, and how far to raise
 * the volume. Deliberately free of Android objects (device types arrive as
 * plain ints) so the rules can be unit-tested on the JVM and read in one
 * screen.
 *
 * The type numbers are the `AudioDeviceInfo.TYPE_*` constants, inlined so
 * this file never touches an API-level-gated symbol (several of them,
 * `TYPE_USB_HEADSET` 26+, `TYPE_HEARING_AID` 28+, `TYPE_BLE_HEADSET` 31+,
 * did not exist on this app's minSdk 24).
 */
internal object AudioRoutePolicy {
    private const val TYPE_WIRED_HEADSET = 3
    private const val TYPE_WIRED_HEADPHONES = 4
    private const val TYPE_BLUETOOTH_SCO = 7
    private const val TYPE_BLUETOOTH_A2DP = 8
    private const val TYPE_USB_DEVICE = 11
    private const val TYPE_USB_HEADSET = 22
    private const val TYPE_HEARING_AID = 23
    private const val TYPE_BLE_HEADSET = 26

    /** Share of the stream's maximum volume the alert is raised to on a headset. */
    const val HEADSET_VOLUME_FRACTION = 0.9

    /**
     * Higher is better, 0 means "not a headset" (built-in speaker, earpiece,
     * HDMI, line out, telephony...). Wired and USB beat Bluetooth because
     * they have no connection latency; A2DP/LE beat SCO because SCO is the
     * narrow-band call channel and `USAGE_MEDIA` is not routed to it unless
     * a call-style SCO link was started.
     */
    fun headsetRank(type: Int): Int = when (type) {
        TYPE_WIRED_HEADSET, TYPE_WIRED_HEADPHONES -> 6
        TYPE_USB_HEADSET -> 5
        TYPE_BLUETOOTH_A2DP, TYPE_BLE_HEADSET -> 4
        TYPE_HEARING_AID -> 3
        TYPE_USB_DEVICE -> 2
        TYPE_BLUETOOTH_SCO -> 1
        else -> 0
    }

    fun isHeadsetType(type: Int): Boolean = headsetRank(type) > 0

    /** Index into [types] of the best headset, or null when none is a headset. */
    fun pickBestHeadsetIndex(types: List<Int>): Int? {
        var bestIndex: Int? = null
        var bestRank = 0
        for ((index, type) in types.withIndex()) {
            val rank = headsetRank(type)
            if (rank > bestRank) {
                bestRank = rank
                bestIndex = index
            }
        }
        return bestIndex
    }

    /** Short stable label Dart shows/tests against: wired, usb, bluetooth, bluetooth_sco, ble, hearing_aid. */
    fun kindLabel(type: Int): String? = when (type) {
        TYPE_WIRED_HEADSET, TYPE_WIRED_HEADPHONES -> "wired"
        TYPE_USB_HEADSET, TYPE_USB_DEVICE -> "usb"
        TYPE_BLUETOOTH_A2DP -> "bluetooth"
        TYPE_BLUETOOTH_SCO -> "bluetooth_sco"
        TYPE_BLE_HEADSET -> "ble"
        TYPE_HEARING_AID -> "hearing_aid"
        else -> null
    }

    /**
     * The volume index to play a headset alert at: [HEADSET_VOLUME_FRACTION]
     * of [max], rounded down, but never below what the rider already chose.
     * It only ever raises: a rider already above the target keeps their own
     * level, and the result is never above `max`.
     */
    fun boostedVolumeIndex(current: Int, max: Int): Int {
        if (max <= 0) return current
        val target = (max * HEADSET_VOLUME_FRACTION).toInt().coerceIn(1, max)
        return maxOf(current, target).coerceAtMost(max)
    }
}

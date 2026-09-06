package id.temankereta.teman_kereta

import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * The finished-trip summary — travel time, distance, average speed — shared
 * by the arrival notification here and the "Perjalanan selesai" screen in
 * Dart (`_TripSummaryStats`).
 *
 * Formatting deliberately mirrors `lib/core/utils/geo.dart`'s
 * `formatDuration`/`formatDistanceMeters`/`formatSpeedKmh` string for
 * string, so the same trip never reads one way in the notification and
 * another way on the screen it opens.
 */
internal data class TripRecap(
    val durationLabel: String,
    val distanceLabel: String,
    val averageSpeedLabel: String,
) {
    val summaryLine: String
        get() = "$durationLabel • $distanceLabel • rata-rata $averageSpeedLabel"

    companion object {
        fun of(durationMillis: Long, distanceMeters: Double): TripRecap {
            val seconds = (durationMillis / 1000).coerceAtLeast(0)
            val averageSpeedKmh = if (seconds > 0) {
                (distanceMeters / 1000.0) / (seconds / 3600.0)
            } else {
                null
            }
            return TripRecap(
                durationLabel = formatDuration(seconds),
                distanceLabel = formatDistance(distanceMeters),
                averageSpeedLabel = formatSpeed(averageSpeedKmh),
            )
        }

        private fun formatDuration(totalSeconds: Long): String {
            val hours = totalSeconds / 3600
            val minutes = (totalSeconds % 3600) / 60
            val seconds = totalSeconds % 60
            return when {
                hours > 0 -> "${hours}j ${minutes.toString().padStart(2, '0')}m"
                minutes > 0 -> "$minutes menit"
                else -> "$seconds detik"
            }
        }

        private fun formatDistance(meters: Double): String {
            if (meters >= 1000) {
                // Matches Dart's `toStringAsFixed(1)` — one decimal, period.
                return "${(meters / 100).roundToLong() / 10.0} km"
            }
            return "${meters.roundToInt()} m"
        }

        private fun formatSpeed(kmh: Double?): String {
            if (kmh == null || kmh.isNaN() || kmh < 0) return "-"
            return "${kmh.roundToInt()} km/j"
        }
    }
}

package id.temankereta.teman_kereta

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** Kotlin port of `lib/core/utils/geo.dart` — kept in sync by hand, both are tiny. */
internal object GeoMath {
    private const val EARTH_RADIUS_METERS = 6_371_000.0
    private const val METERS_PER_DEGREE_LATITUDE = 111_132.0
    private const val METERS_PER_DEGREE_LONGITUDE_AT_EQUATOR = 111_320.0

    fun haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_METERS * c
    }

    /** Initial great-circle bearing from point 1 to point 2, in degrees [0, 360). */
    fun bearingDegrees(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val phi1 = Math.toRadians(lat1)
        val phi2 = Math.toRadians(lat2)
        val dLon = Math.toRadians(lon2 - lon1)
        val y = sin(dLon) * cos(phi2)
        val x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLon)
        val theta = atan2(y, x)
        return (Math.toDegrees(theta) + 360.0) % 360.0
    }

    /**
     * Where a point falls relative to the straight segment between two
     * stations: [crossTrackMeters] is its perpendicular distance from the
     * segment (how far off the rail corridor it is), [fraction] is how far
     * along the segment the closest point sits, clamped to 0..1 (0 = still
     * level with the first station, 1 = level with the second).
     *
     * Used by [TripProgressEngine] to answer "which hop of the route is the
     * rider actually on right now?" after a GPS/signal gap, instead of only
     * ever asking "are they at the one station we expect next?" — the
     * question that leaves a trip permanently stuck when the answer is no.
     */
    data class SegmentMatch(val crossTrackMeters: Double, val fraction: Double)

    fun segmentMatch(
        lat: Double,
        lon: Double,
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double,
    ): SegmentMatch {
        // Equirectangular projection onto a local plane centred on the fix.
        // Adjacent KRL stations are a few km apart at most, where this is
        // accurate to well under a metre — far below the GPS noise it's
        // being compared against.
        val metersPerDegreeLongitude = METERS_PER_DEGREE_LONGITUDE_AT_EQUATOR * cos(Math.toRadians(lat))
        val ax = (lon1 - lon) * metersPerDegreeLongitude
        val ay = (lat1 - lat) * METERS_PER_DEGREE_LATITUDE
        val bx = (lon2 - lon) * metersPerDegreeLongitude
        val by = (lat2 - lat) * METERS_PER_DEGREE_LATITUDE
        val dx = bx - ax
        val dy = by - ay
        val lengthSquared = dx * dx + dy * dy
        if (lengthSquared <= 0.0) {
            return SegmentMatch(sqrt(ax * ax + ay * ay), 0.0)
        }
        val fraction = (-(ax * dx + ay * dy) / lengthSquared).coerceIn(0.0, 1.0)
        val closestX = ax + fraction * dx
        val closestY = ay + fraction * dy
        return SegmentMatch(sqrt(closestX * closestX + closestY * closestY), fraction)
    }
}

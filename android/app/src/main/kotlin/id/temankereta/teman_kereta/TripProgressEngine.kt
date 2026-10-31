package id.temankereta.teman_kereta

import android.content.Context
import android.location.Location

/**
 * Native port of `ActiveTripController.advanceStop()` (Dart) — the trip
 * state machine now lives here because this service is the only thing
 * guaranteed to keep running once the Flutter engine is torn down (app
 * swiped from Recents). Dart still restores/displays this state via
 * `NativeStateStore.activeTripFullState` and keeps a manual "Lanjut" button
 * as a fallback, but authoritative advancement + notification firing happens
 * on every accepted GPS fix, right here.
 *
 * Progression is proximity-based (no geofences — see the plan doc for why),
 * and answers two different questions on every fix:
 *
 * 1. **"Did we just reach the next station?"** — the normal, tight gate:
 *    two consecutive, accuracy-gated fixes that both sit inside
 *    [ARRIVAL_RADIUS_METERS] of a station ahead AND are strictly closer than
 *    the previous accepted fix, so a noisy/spoofed fix can never silently
 *    claim a stop was reached.
 * 2. **"Which hop of the route are we actually on?"** — the catch-up gate,
 *    added because question 1 alone leaves a trip permanently stuck the
 *    moment a single arrival is missed (GPS or network lost between two
 *    stations, a fix rejected by the accuracy ceiling, a tunnel). It
 *    projects the fix onto the route's own station-to-station segments; if
 *    the rider is demonstrably on a *later* hop than the trip thinks, every
 *    station in between is auto-completed at once. This is what makes
 *    "signal died at Universitas Pancasila, came back at Depok Baru"
 *    resume at Depok Baru instead of waiting forever for Lenteng Agung.
 *
 * Distance is measured along the rails, not GPS-to-GPS: each fix is
 * projected onto the real track of the hop the rider is on (sent from Dart
 * per station pair, see `railTrackBetween`), and the odometer is the track
 * length of every completed hop plus how far along the current one the fix
 * sits ([hopProgress]). A hop with no known geometry falls back to the
 * straight line between its stations. This also makes a catch-up jump
 * report the real distance travelled rather than what the GPS gap recorded.
 */
internal class TripProgressEngine(
    private val context: Context,
    /**
     * Invoked after this engine changes which station the trip is at, so
     * the caller can re-post whatever it renders from that state. Without
     * it the ongoing foreground notification and the home-screen widget are
     * posted once at trip start and then never again — they sat frozen on
     * the origin station for the whole journey, which reads to a rider as
     * "the app is stuck" even while tracking is working perfectly
     * (confirmed on-device: the trip page showed Depok Baru while the
     * notification still said "Pasar Minggu → Tanjung Barat").
     */
    private val onStationAdvanced: () -> Unit = {},
) {
    private val notifier = TripNotifier(context)

    private var proximityStreak = 0
    private var proximityStreakIndex = -1
    private var proximityStreakAtStation = false
    private var lastDistanceToCandidateMeters: Double? = null
    private var approachStreak = 0
    private var approachStreakIndex = -1

    fun shutdown() {
        notifier.shutdown()
    }

    /**
     * Called by [ActiveTripLocationService] for every GPS fix accepted by its own jitter/accuracy
     * gates. [fallbackSpeedMps] is the distance/time-derived speed for this fix — only non-null
     * when the fix itself had no usable reported speed (`hasSpeed()` false, or a flat 0 some
     * devices/emulators report regardless of real movement); a genuine reported speed always wins.
     */
    fun onAcceptedFix(location: Location, fallbackSpeedMps: Double? = null) {
        val stations = NativeStateStore.routeStations(context)
        if (stations.isEmpty()) return

        val currentIndex = NativeStateStore.currentStationIndex(context)
        val lastIndex = stations.size - 1
        val storedDistance = NativeStateStore.distanceMeters(context)
        // `fallbackSpeedMps` is only non-null when the caller already
        // decided the fix's own reported speed isn't usable (see
        // ActiveTripLocationService.MIN_USABLE_REPORTED_SPEED_MPS) — so a
        // genuine reported speed, when present, always takes precedence.
        val speedKmh = when {
            fallbackSpeedMps != null -> (fallbackSpeedMps * 3.6).toFloat()
            location.hasSpeed() -> location.speed * 3.6f
            else -> null
        }

        if (currentIndex >= lastIndex) {
            // Already at/after the last station — nothing left to advance
            // into. Watch only for the "overshoot while asleep" case: got
            // close to the destination once, then moved meaningfully away
            // again without the arrival trigger ever having fired (that
            // path is handled below, before this branch would be reached,
            // so reaching here means arrival already fired normally).
            NativeStateStore.applyProgressUpdate(context, distanceMeters = storedDistance, speedKmh = speedKmh)
            return
        }

        val hop = hopProgress(location, stations, currentIndex)
        // The odometer only grows: a fix that projects a little behind the
        // last one (GPS noise, a stop) must not wind it back.
        val distanceSoFar = maxOf(storedDistance, routeDistanceMeters(stations, currentIndex) + hop.alongMeters)
        // Latched until the next station is reached, so a train standing at
        // a signal just past the platform still reads "in transit".
        val departed = NativeStateStore.departed(context) || hop.alongMeters >= DEPARTED_METERS

        val nextIndex = currentIndex + 1
        val next = stations[nextIndex]
        val distanceToNext = GeoMath.haversineMeters(location.latitude, location.longitude, next.latitude, next.longitude)

        // Destination overshoot watch: track the closest the rider ever got
        // to the *destination* station on its final approach hop. If they
        // got reasonably close (train genuinely passed near it) but the
        // proximity/streak gate below never fired, and distance is now
        // growing again well past that minimum, they likely stayed on board
        // past their stop (the exact "ketiduran" scenario this feature is
        // for) — never inferred from a single fix, only a sustained regrowth.
        val destinationId = NativeStateStore.destinationStationId(context)
        if (next.id == destinationId) {
            val priorMin = NativeStateStore.minDestinationDistanceMeters(context)
            val newMin = if (priorMin == null) distanceToNext else minOf(priorMin, distanceToNext)
            if (priorMin != null && priorMin <= OVERSHOOT_WATCH_RADIUS_METERS &&
                distanceToNext - priorMin >= OVERSHOOT_REGROWTH_METERS
            ) {
                markMissedDestination(distanceSoFar, speedKmh)
                return
            }
            NativeStateStore.applyProgressUpdate(
                context,
                distanceMeters = distanceSoFar,
                speedKmh = speedKmh,
                minDestinationDistanceMeters = newMin,
                distanceToNextMeters = hop.remainingMeters,
                departed = departed,
                hopFraction = hop.fraction,
            )
        } else {
            NativeStateStore.applyProgressUpdate(
                context,
                distanceMeters = distanceSoFar,
                speedKmh = speedKmh,
                distanceToNextMeters = hop.remainingMeters,
                departed = departed,
                hopFraction = hop.fraction,
            )
        }

        if (location.accuracy > PROXIMITY_ACCURACY_CEILING_METERS) {
            return
        }

        announceDepartureFromTransfer(location, stations, currentIndex)
        announceApproach(location, stations, currentIndex)

        val candidate = resolveReachedIndex(location, stations, currentIndex)
        if (candidate == null) {
            resetStreak()
            return
        }
        if (candidate.index != proximityStreakIndex || candidate.atStation != proximityStreakAtStation) {
            resetStreak()
            proximityStreakIndex = candidate.index
            proximityStreakAtStation = candidate.atStation
        }
        if (candidate.atStation) {
            val previousDistance = lastDistanceToCandidateMeters
            lastDistanceToCandidateMeters = candidate.distanceMeters
            if (previousDistance != null && candidate.distanceMeters > previousDistance) {
                // Inside the radius but moving away again (e.g. an express
                // train passing close without stopping) — don't count it.
                proximityStreak = 0
                return
            }
        }
        proximityStreak += 1
        val required = if (candidate.index == nextIndex) {
            REQUIRED_CONSECUTIVE_FIXES
        } else {
            // A multi-station jump rewrites more of the trip at once, so it
            // asks for more agreement before it's believed.
            REQUIRED_CONSECUTIVE_CATCH_UP_FIXES
        }
        if (proximityStreak < required) {
            return
        }

        // Re-read fresh right before mutating — guards the (rare) case of
        // two fixes racing through this method concurrently.
        val freshIndex = NativeStateStore.currentStationIndex(context)
        if (freshIndex != currentIndex) {
            return
        }
        advanceStop(freshIndex, candidate.index, stations, distanceSoFar)
        resetStreak()
    }

    private fun resetStreak() {
        proximityStreak = 0
        proximityStreakIndex = -1
        proximityStreakAtStation = false
        lastDistanceToCandidateMeters = null
    }

    /**
     * The furthest station index the fix can be said to have reached, or
     * null when the rider is still on the hop the trip already thinks
     * they're on (the normal, nothing-to-do case).
     *
     * [Candidate.atStation] distinguishes "standing at that station"
     * (question 1 above — subject to the closing-distance check) from
     * "already past it, somewhere on the following hop" (question 2, the
     * catch-up after a signal gap).
     */
    private fun resolveReachedIndex(
        location: Location,
        stations: List<NativeStateStore.RouteStation>,
        currentIndex: Int,
    ): Candidate? {
        val lastIndex = stations.size - 1
        var nearestIndex = -1
        var nearestDistance = Double.MAX_VALUE
        for (index in currentIndex + 1..lastIndex) {
            val station = stations[index]
            val distance = GeoMath.haversineMeters(
                location.latitude,
                location.longitude,
                station.latitude,
                station.longitude,
            )
            if (distance < nearestDistance) {
                nearestDistance = distance
                nearestIndex = index
            }
        }
        if (nearestIndex >= 0 && nearestDistance <= ARRIVAL_RADIUS_METERS) {
            return Candidate(nearestIndex, nearestDistance, atStation = true)
        }

        var bestSegment = -1
        var bestCrossTrack = Double.MAX_VALUE
        var bestFraction = 0.0
        for (index in currentIndex until lastIndex) {
            val from = stations[index]
            val to = stations[index + 1]
            val match = GeoMath.segmentMatch(
                location.latitude,
                location.longitude,
                from.latitude,
                from.longitude,
                to.latitude,
                to.longitude,
            )
            if (match.crossTrackMeters < bestCrossTrack) {
                bestCrossTrack = match.crossTrackMeters
                bestSegment = index
                bestFraction = match.fraction
            }
        }
        if (bestSegment > currentIndex &&
            bestCrossTrack <= CORRIDOR_RADIUS_METERS &&
            bestFraction >= MIN_SEGMENT_FRACTION
        ) {
            return Candidate(bestSegment, nearestDistance, atStation = false)
        }
        return null
    }

    /**
     * The 200 m transit/arrival announcement before the next transfer station or the
     * destination, whichever comes first. Measured straight to that station
     * rather than waiting for [advanceStop], so it does not depend on the
     * tight 120 m arrival gate surviving GPS jitter at the platform. Two
     * agreeing fixes are required so a single wild fix can't ring it early;
     * sounds once per station, persisted so a service restart can't repeat it.
     */
    private fun announceApproach(
        location: Location,
        stations: List<NativeStateStore.RouteStation>,
        currentIndex: Int,
    ) {
        val lastIndex = stations.size - 1
        val transferIndex = NativeStateStore.transferBoundaries(context)
            .filter { it.index > currentIndex }
            .minOfOrNull { it.index }
        val keyIndex = transferIndex ?: lastIndex
        if (NativeStateStore.approachAlertedIndex(context) == keyIndex) return
        val station = stations[keyIndex]
        val distance = GeoMath.haversineMeters(location.latitude, location.longitude, station.latitude, station.longitude)
        if (keyIndex != approachStreakIndex || distance > APPROACH_ALERT_RADIUS_METERS) {
            approachStreakIndex = keyIndex
            approachStreak = if (distance > APPROACH_ALERT_RADIUS_METERS) 0 else 1
            return
        }
        approachStreak += 1
        if (approachStreak < REQUIRED_CONSECUTIVE_FIXES) return
        approachStreak = 0
        NativeStateStore.setApproachAlertedIndex(context, keyIndex)
        val isTransfer = transferIndex != null
        val name = if (isTransfer) {
            station.name
        } else {
            val destinationId = NativeStateStore.destinationStationId(context)
            stations.firstOrNull { it.id == destinationId }?.name ?: station.name
        }
        notifier.showApproachAlert(
            name,
            isTransfer = isTransfer,
            vibrate = NativeStateStore.vibrationEnabled(context),
            sound = NativeStateStore.soundEnabled(context),
        )
    }

    /**
     * The countdown that arriving at a transfer station swallows. Arrival
     * there announces only "saatnya transit", so when the destination (or
     * the next transfer) is within the alert threshold of it — say one
     * station after the transfer — the "1 stasiun lagi" voice and its bell
     * never sounded at all. It is announced here instead, once the rider is
     * demonstrably on the next train: [DEPARTURE_RADIUS_METERS] away from
     * the transfer station.
     */
    private fun announceDepartureFromTransfer(
        location: Location,
        stations: List<NativeStateStore.RouteStation>,
        currentIndex: Int,
    ) {
        if (NativeStateStore.tripState(context) != "transferring") return
        if (NativeStateStore.departureAlertedIndex(context) == currentIndex) return
        val here = stations[currentIndex]
        val distance = GeoMath.haversineMeters(location.latitude, location.longitude, here.latitude, here.longitude)
        if (distance < DEPARTURE_RADIUS_METERS) return
        NativeStateStore.setDepartureAlertedIndex(context, currentIndex)
        // Already close enough for the approach alert: that one says more.
        if (NativeStateStore.approachAlertedIndex(context) > currentIndex) return

        val vibrate = NativeStateStore.vibrationEnabled(context)
        val sound = NativeStateStore.soundEnabled(context)
        val threshold = NativeStateStore.stopAlertThreshold(context)
        val boundary = NativeStateStore.transferBoundaries(context)
            .filter { it.index > currentIndex }
            .minByOrNull { it.index }
        if (boundary != null) {
            val stopsToTransfer = boundary.index - currentIndex
            if (stopsToTransfer in 1..threshold) {
                val transferStation = stations.getOrNull(boundary.index)?.name ?: return
                notifier.showTransferApproachingAlert(stopsToTransfer, transferStation, vibrate, sound)
            }
            return
        }
        val remaining = stations.size - 1 - currentIndex
        if (remaining in 1..threshold) {
            val destinationId = NativeStateStore.destinationStationId(context)
            val destinationName = stations.firstOrNull { it.id == destinationId }?.name ?: stations.last().name
            notifier.showStopAlert(remaining, destinationName, vibrate, sound)
        }
    }

    private data class Candidate(val index: Int, val distanceMeters: Double, val atStation: Boolean)

    /** Cumulative route length along the rails from the origin up to [index]. */
    private fun routeDistanceMeters(stations: List<NativeStateStore.RouteStation>, index: Int): Double {
        var total = 0.0
        for (hop in 0 until index.coerceAtMost(stations.size - 1)) {
            total += hopLengthMeters(stations, hop)
        }
        return total
    }

    /** Length of the hop from station [index] to the next: its track, or the straight line. */
    private fun hopLengthMeters(stations: List<NativeStateStore.RouteStation>, index: Int): Double {
        val from = stations[index]
        val to = stations[index + 1]
        val track = from.trackToNext
        if (track != null) return GeoMath.projectOntoPolyline(from.latitude, from.longitude, track).lengthMeters
        return GeoMath.haversineMeters(from.latitude, from.longitude, to.latitude, to.longitude)
    }

    private data class HopProgress(val alongMeters: Double, val remainingMeters: Double) {
        /** 0 at the station just reached, 1 at the next. */
        val fraction: Double
            get() = (alongMeters + remainingMeters).let { if (it > 0) alongMeters / it else 0.0 }
    }

    /**
     * How far the fix is along the hop from station [index] to the next, and
     * how far is left, both along the track. A fix too far off the track to
     * be on it (or a hop with no geometry) is measured by straight line to
     * the next station instead.
     */
    private fun hopProgress(
        location: Location,
        stations: List<NativeStateStore.RouteStation>,
        index: Int,
    ): HopProgress {
        val from = stations[index]
        val to = stations[index + 1]
        val track = from.trackToNext
        if (track != null) {
            val match = GeoMath.projectOntoPolyline(location.latitude, location.longitude, track)
            if (match.offsetMeters <= CORRIDOR_RADIUS_METERS) {
                return HopProgress(match.alongMeters, (match.lengthMeters - match.alongMeters).coerceAtLeast(0.0))
            }
        }
        val length = GeoMath.haversineMeters(from.latitude, from.longitude, to.latitude, to.longitude)
        val remaining = GeoMath.haversineMeters(location.latitude, location.longitude, to.latitude, to.longitude)
        return HopProgress((length - remaining).coerceIn(0.0, length), remaining)
    }

    /**
     * Moves the trip from [currentIndex] to [targetIndex]. [targetIndex] is
     * usually `currentIndex + 1`, but is further ahead whenever the
     * catch-up gate resolved a later hop — every station in between is
     * completed silently in that case, and only the state the rider is
     * *now* in gets announced, so a recovered signal gap never replays a
     * backlog of stale "3 stasiun lagi" alerts.
     */
    private fun advanceStop(
        currentIndex: Int,
        targetIndex: Int,
        stations: List<NativeStateStore.RouteStation>,
        distanceSoFar: Double,
    ) {
        val lastIndex = stations.size - 1
        val nextIndex = targetIndex.coerceIn(currentIndex + 1, lastIndex)
        val remaining = lastIndex - nextIndex
        val boundaries = NativeStateStore.transferBoundaries(context)
        val boundary = boundaries.filter { it.index >= nextIndex }.minByOrNull { it.index }
        val nextState = when {
            boundary != null && boundary.index == nextIndex -> "transferring"
            boundary != null && boundary.index - nextIndex <= 3 -> "approachingTransfer"
            remaining <= 0 -> "arrived"
            remaining <= 3 -> "approachingDestination"
            else -> "onBoard"
        }
        val nextStation = stations[nextIndex]
        val followingStation = stations.getOrNull(nextIndex + 1)

        NativeStateStore.applyProgressUpdate(
            context,
            distanceMeters = maxOf(distanceSoFar, routeDistanceMeters(stations, nextIndex)),
            speedKmh = null,
            currentStationIndex = nextIndex,
            state = nextState,
            currentStationId = nextStation.id,
            currentStationName = nextStation.name,
            nextStationId = followingStation?.id,
            nextStationName = followingStation?.name,
            remainingStations = remaining,
            pendingCompletionLog = if (nextState == "arrived") true else null,
            distanceToNextMeters = if (nextIndex < lastIndex) hopLengthMeters(stations, nextIndex) else 0.0,
            departed = false,
            hopFraction = 0.0,
        )

        onStationAdvanced()

        val vibrate = NativeStateStore.vibrationEnabled(context)
        val soundEnabled = NativeStateStore.soundEnabled(context)
        // The 200 m approach alert already announced this station; the
        // arrival/transfer notification still posts, silently.
        val sound = soundEnabled && NativeStateStore.approachAlertedIndex(context) != nextIndex
        val threshold = NativeStateStore.stopAlertThreshold(context)

        when {
            nextState == "arrived" -> {
                // The trip finishes here rather than waiting for a tap, so
                // this is a summary, not a warning — see `showArrivalAlert`.
                val destinationId = NativeStateStore.destinationStationId(context)
                val destinationName = stations.firstOrNull { it.id == destinationId }?.name ?: nextStation.name
                val startedAt = NativeStateStore.startedAtEpochMs(context)
                notifier.showArrivalAlert(
                    destinationName,
                    durationMillis = if (startedAt > 0) System.currentTimeMillis() - startedAt else 0L,
                    distanceMeters = maxOf(distanceSoFar, routeDistanceMeters(stations, nextIndex)),
                    vibrate = vibrate,
                    sound = sound,
                )
            }
            nextState == "transferring" -> {
                notifier.showTransferAlert(nextStation.name, boundary?.instruction, vibrate, sound)
            }
            boundary != null -> {
                val stopsToTransfer = boundary.index - nextIndex
                if (stopsToTransfer in 1..threshold) {
                    val transferStation = stations.getOrNull(boundary.index)?.name ?: nextStation.name
                    notifier.showTransferApproachingAlert(stopsToTransfer, transferStation, vibrate, sound)
                }
            }
            remaining <= threshold -> {
                val destinationId = NativeStateStore.destinationStationId(context)
                val destinationName = stations.firstOrNull { it.id == destinationId }?.name ?: nextStation.name
                notifier.showStopAlert(remaining, destinationName, vibrate, sound)
            }
        }
    }

    private fun markMissedDestination(distanceSoFar: Double, speedKmh: Float?) {
        NativeStateStore.applyProgressUpdate(
            context,
            distanceMeters = distanceSoFar,
            speedKmh = speedKmh,
            state = "missedDestination",
            pendingMissedLog = true,
        )
        onStationAdvanced()
        val destinationId = NativeStateStore.destinationStationId(context)
        val stations = NativeStateStore.routeStations(context)
        val destinationName = stations.firstOrNull { it.id == destinationId }?.name ?: "tujuan"
        notifier.showMissedDestinationAlert(
            destinationName,
            NativeStateStore.vibrationEnabled(context),
            NativeStateStore.soundEnabled(context),
        )
    }

    companion object {
        // Tighter than the old geofence default (250m) — this is the sole
        // trigger for advancing a stop now, so it deliberately errs toward
        // "confirm a real arrival" over "confirm it fast".
        private const val ARRIVAL_RADIUS_METERS = 120.0
        private const val PROXIMITY_ACCURACY_CEILING_METERS = 50f
        private const val REQUIRED_CONSECUTIVE_FIXES = 2
        private const val REQUIRED_CONSECUTIVE_CATCH_UP_FIXES = 3
        // How far off the straight line between two consecutive stations a
        // fix may sit and still count as "on that hop". Generous enough for
        // the curve a real rail alignment takes between two stations plus
        // ordinary urban GPS error, tight enough that a rider who is
        // genuinely somewhere else entirely matches no hop at all.
        private const val CORRIDOR_RADIUS_METERS = 600.0
        // Guards the seam between two hops: a fix level with a station
        // (fraction ~0) is ambiguous between the hop before it and the hop
        // after, so a catch-up needs the rider to be demonstrably *along*
        // the later hop before it rewrites the trip.
        private const val MIN_SEGMENT_FRACTION = 0.08
        private const val OVERSHOOT_WATCH_RADIUS_METERS = 300.0
        private const val OVERSHOOT_REGROWTH_METERS = 400.0
        // Ahead of ARRIVAL_RADIUS_METERS on purpose: the announcement must not wait
        // for the arrival gate, which jitter at the platform can delay.
        const val APPROACH_ALERT_RADIUS_METERS = 200.0
        // Wide enough that walking a long interchange (Manggarai) does not
        // count as having left on the next train.
        private const val DEPARTURE_RADIUS_METERS = 500.0
        // Along the track from the station just reached: past this the
        // train has left it, and the trip reads "dalam perjalanan".
        private const val DEPARTED_METERS = 300.0
    }
}

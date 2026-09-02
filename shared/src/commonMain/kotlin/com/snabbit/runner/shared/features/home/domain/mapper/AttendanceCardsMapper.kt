package com.snabbit.runner.shared.features.home.domain.mapper

import com.snabbit.runner.shared.core.location.SnabbitLocation
import com.snabbit.runner.shared.core.location.distanceMeters
import com.snabbit.runner.shared.core.location.formatDistance
import com.snabbit.runner.shared.features.shift.core.domain.model.AttendanceStatus
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.shift.core.domain.model.Hotspot

/**
 * Pure projection: typed shift + runner location → ordered list of UI cards.
 *
 * [runnerLocation] is the most recent GPS fix (null = no fix yet / failed).
 * The hotspot distance label is computed from `runner ↔ hotspot.lat/lng` and
 * formatted via [formatDistance]; missing inputs collapse to `null` (the
 * card hides the distance line).
 */
fun attendanceCardsFrom(
    shift: com.snabbit.runner.shared.features.shift.core.domain.model.Shift?,
    runnerLocation: SnabbitLocation? = null,
    nowMs: Long? = null,
): List<HomeCard> {
    if (shift == null) return emptyList()
    // Login-enable = BE `enable_login` OR the on-device geofence (product
    // decision). BE stays authoritative when it says yes: `enable_login = true`
    // enables login directly, no location needed — so a runner BE has cleared is
    // never stranded by denied/flaky GPS. When BE says no, we fall back to the
    // geofence and enable iff the runner is provably within login_radius of the
    // hotspot (fails CLOSED — no coords / no GPS fix → stays disabled).
    //
    // The geofence trusts only a RECENT fix: on cold start `_runnerLocation` is
    // seeded from `getLastKnownLocation()`, which can be a cached fix from when
    // the runner WAS at the hotspot — that must not open login BE has denied.
    // The distance label / map centring still use the raw fix (a slightly old
    // fix is fine there); only the login gate is freshness-gated. `nowMs == null`
    // (previews/tests) skips the check so behaviour there is unchanged.
    val fixForGate = runnerLocation?.takeIf {
        nowMs == null || nowMs - it.collectedAt <= MAX_LOGIN_FIX_AGE_MS
    }
    val canLogin = (shift.hotspot?.canLoginNow ?: false) ||
        strictlyWithinLoginRadius(shift.hotspot, fixForGate)
    return buildList {
        val today = shift.today
        if (today != null && shift.effectiveAttendance != AttendanceStatus.Pending) {
            add(HomeCard.Attendance.TodayStatus(
                day = today, status = shift.effectiveAttendance,
                canChange = shift.canChangeAttendance, noShowRedCards = shift.noShowRedCards,
                canLoginNow = canLogin,
                isProvisional = shift.isProvisional,
            ))
        }
        shift.tomorrow?.let { add(HomeCard.Attendance.TomorrowProvisional(it)) }
        shift.hotspot?.let { h ->
            // Hotspot nav card (Figma DS 1491:13181) — pre-shift phase
            // only. The VM filters this out when the phase is the Map
            // archetype (SearchingForJobs / WAIT_HOTSPOT), because the
            // hotspot info is already shown by the bg map + floating
            // widget there.
            add(
                HomeCard.ShiftLogin(
                    hotspotName = h.name,
                    reached = canLogin,
                    distanceLabel = hotspotDistanceMeters(h, runnerLocation)
                        ?.let(::formatDistance),
                    canLoginNow = canLogin,
                    lat = h.lat,
                    lng = h.lng,
                ),
            )
        }
    }
}

/**
 * On-device login geofence — the FALLBACK the caller ORs with BE `enable_login`:
 * returns `true` iff we can PROVE the runner is within `login_radius` metres of
 * the hotspot ([DEFAULT_LOGIN_RADIUS_M] when BE omits it). Fails CLOSED — a
 * missing hotspot, missing coords, or no GPS fix returns `false`, so the local
 * path never enables login without a real in-radius fix. (When BE `enable_login`
 * is true the caller enables login directly and this is not consulted.)
 */
internal fun strictlyWithinLoginRadius(
    hotspot: Hotspot?,
    runnerLocation: SnabbitLocation?,
): Boolean {
    val h = hotspot ?: return false
    val distance = hotspotDistanceMeters(h, runnerLocation) ?: return false
    return distance <= (h.loginRadiusMeters ?: DEFAULT_LOGIN_RADIUS_M)
}

/**
 * Runner→hotspot great-circle distance in metres. Returns `null` when either
 * the hotspot coords or the runner's GPS fix is unavailable (the card hides
 * its distance line, and the login geofence fails CLOSED — [strictlyWithinLoginRadius]
 * treats a null distance as "not proven in range" and leaves login disabled).
 */
internal fun hotspotDistanceMeters(
    hotspot: Hotspot,
    runnerLocation: SnabbitLocation?,
): Double? {
    val hLat = hotspot.lat ?: return null
    val hLng = hotspot.lng ?: return null
    val loc = runnerLocation ?: return null
    return distanceMeters(
        startLatitude = loc.latitude,
        startLongitude = loc.longitude,
        endLatitude = hLat,
        endLongitude = hLng,
    )
}

/** Fallback login geofence radius when `RUNNER_LOGIN_HOTSPOT.login_radius` is absent. */
internal const val DEFAULT_LOGIN_RADIUS_M = 100

/** Max age of a GPS fix the login geofence will trust (2 min). Older fixes still
 *  drive the distance label / map centre, but never open login on their own —
 *  a stale last-known fix must not enable login the BE has denied. */
internal const val MAX_LOGIN_FIX_AGE_MS = 120_000L

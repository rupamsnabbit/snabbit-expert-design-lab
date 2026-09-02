package com.snabbit.runner.shared.features.home.domain.mapper

import com.snabbit.runner.shared.core.location.SnabbitLocation
import com.snabbit.runner.shared.features.shift.core.domain.model.AttendanceStatus
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.shift.core.domain.model.Hotspot
import com.snabbit.runner.shared.features.shift.core.domain.model.Shift
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftDay
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue

class AttendanceCardsMapperTest {
    private val tomorrow = ShiftDay("Wed, 8 Feb", "7am-12pm", "₹800", false)
    private val today = ShiftDay("Tue, 7 Feb", "7am-12pm", null, false)

    @Test fun nullShift_emptyList() {
        assertTrue(attendanceCardsFrom(null).isEmpty())
    }

    @Test fun tomorrowOnly_yieldsTomorrowCard() {
        val cards = attendanceCardsFrom(
            Shift(AttendanceStatus.Pending, null, null, tomorrow, false, 0),
        )
        assertIs<HomeCard.Attendance.TomorrowProvisional>(cards.single())
    }

    @Test fun confirmedToday_yieldsTodayStatusOnly() {
        val cards = attendanceCardsFrom(Shift(AttendanceStatus.Present, null, today, null, true, 0))
        val c = assertIs<HomeCard.Attendance.TodayStatus>(cards.single())
        assertEquals(AttendanceStatus.Present, c.status)
        assertTrue(c.canChange)
    }

    @Test fun absentToday_withTomorrow_yieldsTwoStackedCards() {
        // Figma 318-43671
        val cards = attendanceCardsFrom(Shift(AttendanceStatus.Absent, null, today, tomorrow, true, 0))
        assertEquals(2, cards.size)
        assertIs<HomeCard.Attendance.TodayStatus>(cards[0])
        assertIs<HomeCard.Attendance.TomorrowProvisional>(cards[1])
    }

    @Test fun optimisticOverridesServer() {
        val cards = attendanceCardsFrom(Shift(AttendanceStatus.Absent, AttendanceStatus.Present, today, null, false, 0))
        val c = assertIs<HomeCard.Attendance.TodayStatus>(cards.single())
        assertEquals(AttendanceStatus.Present, c.status)
    }

    @Test fun pendingTodayAlone_emptyList() {
        // Pending today renders via Flutter CurrentDayAttendance; not on CMP home this PR.
        assertTrue(attendanceCardsFrom(Shift(AttendanceStatus.Pending, null, today, null, false, 0)).isEmpty())
    }

    @Test fun noShowRedCards_propagate() {
        val cards = attendanceCardsFrom(Shift(AttendanceStatus.Absent, null, today, null, false, 3))
        assertEquals(3, (cards.single() as HomeCard.Attendance.TodayStatus).noShowRedCards)
    }

    // ── Login gate — BE enable_login OR on-device geofence ──────────────────
    // BE `enable_login` = true enables login directly (no location needed).
    // BE = false falls back to the geofence: enabled iff within login_radius,
    // fails CLOSED (no coords / no GPS fix → disabled).
    // Hotspot at (19.0, 72.9); 0.001° latitude ≈ 111 m.

    private val hotspotOrigin = Hotspot("Gate 1", 19.0, 72.9, null, canLoginNow = true)
    private fun at(latOffset: Double) = SnabbitLocation(
        latitude = 19.0 + latOffset, longitude = 72.9, accuracy = null,
        timestamp = 0L, collectedAt = 0L,
    )
    private fun shiftWith(hotspot: Hotspot) =
        Shift(AttendanceStatus.Present, null, today, null, false, 0, hotspot = hotspot)
    private fun loginCard(shift: Shift, loc: SnabbitLocation?) =
        attendanceCardsFrom(shift, loc).filterIsInstance<HomeCard.ShiftLogin>().single()

    @Test fun beEnabled_enablesLogin() {
        val card = loginCard(shiftWith(hotspotOrigin), at(0.0005)) // ~55 m
        assertTrue(card.canLoginNow)
        assertTrue(card.reached)
    }

    @Test fun beEnabled_enablesLogin_evenWhenFar() {
        // BE enable_login = true is authoritative on its own — no location needed,
        // so distance is irrelevant when BE has cleared login.
        val card = loginCard(shiftWith(hotspotOrigin), at(0.002)) // ~222 m
        assertTrue(card.canLoginNow)
    }

    @Test fun beEnabled_enablesLogin_evenWithoutGpsFix() {
        // BE = true doesn't need a fix → a runner BE cleared isn't stranded by GPS.
        assertTrue(loginCard(shiftWith(hotspotOrigin), loc = null).canLoginNow)
    }

    @Test fun beDisabled_butAtHotspot_loginEnabled() {
        // Fallback: BE enable_login = false, but the runner is physically within
        // radius → the on-device geofence enables login.
        val beOff = hotspotOrigin.copy(canLoginNow = false)
        assertTrue(loginCard(shiftWith(beOff), at(0.0)).canLoginNow)
    }

    @Test fun beDisabled_andFar_loginDisabled() {
        // BE off + provably too far → disabled (both card surfaces gated identically).
        val beOff = hotspotOrigin.copy(canLoginNow = false)
        val cards = attendanceCardsFrom(shiftWith(beOff), at(0.002)) // ~222 m
        assertFalse(cards.filterIsInstance<HomeCard.ShiftLogin>().single().canLoginNow)
        assertFalse(cards.filterIsInstance<HomeCard.Attendance.TodayStatus>().single().canLoginNow)
    }

    @Test fun beDisabled_noGpsFix_failsClosed_loginDisabled() {
        // BE off + no fix → the geofence can't prove presence → disabled.
        val beOff = hotspotOrigin.copy(canLoginNow = false)
        assertFalse(loginCard(shiftWith(beOff), loc = null).canLoginNow)
    }

    @Test fun beDisabled_noHotspotCoords_failsClosed_loginDisabled() {
        val beOff = hotspotOrigin.copy(canLoginNow = false, lat = null, lng = null)
        assertFalse(loginCard(shiftWith(beOff), at(0.01)).canLoginNow)
    }

    @Test fun beDisabled_beRadiusOverridesDefault() {
        // BE off, so the geofence decides: ~333 m is outside the 100 m default
        // but inside the BE-sent 500 m radius → enabled.
        val wide = hotspotOrigin.copy(canLoginNow = false, loginRadiusMeters = 500)
        assertTrue(loginCard(shiftWith(wide), at(0.003)).canLoginNow)
    }

    // ── Login gate — fix freshness (fixes at collectedAt = 0L) ──────────────

    @Test fun beDisabled_atHotspot_butStaleFix_loginDisabled() {
        // In-radius, but the fix is older than MAX_LOGIN_FIX_AGE_MS — a cached
        // last-known fix from when the runner WAS here must not open login.
        val beOff = hotspotOrigin.copy(canLoginNow = false)
        val cards = attendanceCardsFrom(shiftWith(beOff), at(0.0), nowMs = MAX_LOGIN_FIX_AGE_MS + 1)
        assertFalse(cards.filterIsInstance<HomeCard.ShiftLogin>().single().canLoginNow)
    }

    @Test fun beDisabled_atHotspot_freshFix_loginEnabled() {
        // Same spot, fix within the freshness window → the geofence opens login.
        val beOff = hotspotOrigin.copy(canLoginNow = false)
        val cards = attendanceCardsFrom(shiftWith(beOff), at(0.0), nowMs = MAX_LOGIN_FIX_AGE_MS)
        assertTrue(cards.filterIsInstance<HomeCard.ShiftLogin>().single().canLoginNow)
    }

    @Test fun beEnabled_staleFix_stillEnabled() {
        // BE authoritative-yes is independent of the fix → freshness irrelevant.
        val cards = attendanceCardsFrom(shiftWith(hotspotOrigin), at(0.0), nowMs = MAX_LOGIN_FIX_AGE_MS + 1)
        assertTrue(cards.filterIsInstance<HomeCard.ShiftLogin>().single().canLoginNow)
    }
}

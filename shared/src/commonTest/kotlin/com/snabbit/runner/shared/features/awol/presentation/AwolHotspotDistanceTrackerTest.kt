package com.snabbit.runner.shared.features.awol.presentation

import com.snabbit.runner.shared.core.location.SnabbitLocation
import com.snabbit.runner.shared.features.awol.domain.AwolHotspot
import com.snabbit.runner.shared.features.awol.domain.AwolPhase
import com.snabbit.runner.shared.features.awol.domain.AwolSnapshot
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * Coverage for [AwolHotspotDistanceTracker]: the HOME_CARD/coordinates gate,
 * per-fix recomputation, degradation when the host has no fix (line hidden,
 * collection kept), and recompute on hotspot change / surface flips.
 *
 * The tracker opens **no location stream of its own** — it reads the host
 * screen's already-running fix (`HomeViewModel.runnerLocation`), so there is
 * exactly one FusedLocationProvider request for the screen instead of two.
 * `subscriptionCount` on the host flow is asserted throughout to pin that: 1
 * while the tile is the live surface, 0 otherwise, and never more than 1.
 */
class AwolHotspotDistanceTrackerTest {

    private class Harness(testScope: TestScope) {
        /** Stands in for `HomeViewModel.runnerLocation` — null = no usable fix. */
        val fixes = MutableStateFlow<SnabbitLocation?>(null)
        val state = MutableStateFlow(AwolUiState())
        val tracker = AwolHotspotDistanceTracker(
            runnerLocation = fixes,
            uiState = state,
            scope = CoroutineScope(
                testScope.backgroundScope.coroutineContext +
                    UnconfinedTestDispatcher(testScope.testScheduler),
            ),
        )
    }

    @Test
    fun surfaceNone_emitsNullAndNeverSubscribesToTheHostFix() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.NONE)

        assertNull(h.tracker.distanceText.value)
        assertEquals(0, h.fixes.subscriptionCount.value)
    }

    @Test
    fun homeCardWithoutCoordinates_emitsNullAndNeverSubscribesToTheHostFix() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(
            AwolSurface.HOME_CARD,
            hotspot = AwolHotspot(name = "HSR", latitude = null, longitude = null),
        )

        assertNull(h.tracker.distanceText.value)
        assertEquals(0, h.fixes.subscriptionCount.value)
    }

    @Test
    fun hostFixAlreadyKnown_paintsImmediatelyFromTheReplayedValue() = runTest {
        // 0.01° of latitude from the hotspot ≈ 1113 m → "1.1 km away". The host
        // StateFlow replays its latest fix, so the line paints without waiting for
        // the next GPS update — what the tracker's own seed call used to buy.
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)

        assertEquals("1.1 km away", h.tracker.distanceText.value)
        assertEquals(1, h.fixes.subscriptionCount.value)
    }

    @Test
    fun noHostFixYet_hidesTheLineUntilOneArrives() = runTest {
        val h = Harness(this)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)
        assertNull(h.tracker.distanceText.value)

        h.fixes.value = fix(12.91, 77.64)

        assertEquals("1.1 km away", h.tracker.distanceText.value)
    }

    @Test
    fun movingFixes_updateTheDistancePerFix() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)
        assertEquals("1.1 km away", h.tracker.distanceText.value)

        // ~11 m from the hotspot.
        h.fixes.value = fix(12.9199, 77.64)

        assertEquals("11m away", h.tracker.distanceText.value)
        // Still ONE subscription — a new fix must not restart the collection.
        assertEquals(1, h.fixes.subscriptionCount.value)
    }

    @Test
    fun hostPublishesNoFix_hidesTheLineButKeepsCollecting() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)
        assertEquals("1.1 km away", h.tracker.distanceText.value)

        // Permission revoked / GPS off / a failed fix — the host publishes null.
        h.fixes.value = null

        assertNull(h.tracker.distanceText.value)
        assertEquals(1, h.fixes.subscriptionCount.value)
    }

    @Test
    fun fixAfterNoFix_restoresTheLine() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)
        h.fixes.value = null
        assertNull(h.tracker.distanceText.value)

        h.fixes.value = fix(12.9199, 77.64)

        assertEquals("11m away", h.tracker.distanceText.value)
    }

    @Test
    fun surfaceFlipToNone_clearsTheTextAndStopsCollecting() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)
        assertEquals("1.1 km away", h.tracker.distanceText.value)

        h.state.value = uiState(AwolSurface.NONE)

        assertNull(h.tracker.distanceText.value)
        assertEquals(0, h.fixes.subscriptionCount.value)
    }

    @Test
    fun hotspotChange_recomputesAgainstTheNewTarget() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)
        assertEquals("1.1 km away", h.tracker.distanceText.value)

        h.state.value = uiState(
            AwolSurface.HOME_CARD,
            hotspot = AwolHotspot(name = "Koramangala", latitude = 12.91, longitude = 77.64),
        )

        assertEquals("0m away", h.tracker.distanceText.value)
        // Re-collected against the new hotspot, but still only one subscription.
        assertEquals(1, h.fixes.subscriptionCount.value)
    }

    @Test
    fun payloadRefreshWithTheSameHotspot_leavesTheLineAlone() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)
        // Countdown ticks re-emit uiState with the same snapshot/hotspot.
        h.state.value = h.state.value.copy(remainingSeconds = 100)

        assertEquals("1.1 km away", h.tracker.distanceText.value)
        assertEquals(1, h.fixes.subscriptionCount.value)
    }

    @Test
    fun start_isIdempotent() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)

        assertEquals("1.1 km away", h.tracker.distanceText.value)
        assertEquals(1, h.fixes.subscriptionCount.value)
    }

    @Test
    fun stop_clearsTheText() = runTest {
        val h = Harness(this)
        h.fixes.value = fix(12.91, 77.64)
        h.tracker.start()
        h.state.value = uiState(AwolSurface.HOME_CARD)
        assertEquals("1.1 km away", h.tracker.distanceText.value)

        h.tracker.stop()

        assertNull(h.tracker.distanceText.value)
    }

    private companion object {
        val HOTSPOT = AwolHotspot(name = "HSR", latitude = 12.92, longitude = 77.64)

        fun fix(latitude: Double, longitude: Double) = SnabbitLocation(
            latitude = latitude,
            longitude = longitude,
            accuracy = 5f,
            timestamp = 0L,
            collectedAt = 0L,
        )

        fun uiState(surface: AwolSurface, hotspot: AwolHotspot? = HOTSPOT) = AwolUiState(
            snapshot = AwolSnapshot(
                eventId = "evt-1",
                phase = AwolPhase.BREACH,
                deadlineMillis = null,
                totalSeconds = 300,
                remainingSeconds = null,
                redCardsTotal = 0,
                showPenaltyRate = false,
                penaltyRateCount = null,
                hotspot = hotspot,
                consequences = emptyList(),
                imageUrl = null,
                titleText = "t",
                warningText = "w",
                badgeText = "b",
                detectedAtMillis = null,
                breachCount = null,
            ),
            surface = surface,
        )
    }
}

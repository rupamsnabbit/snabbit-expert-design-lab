package com.snabbit.runner.shared.features.awol.presentation

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.permissions.PermissionManager
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import com.snabbit.runner.shared.core.permissions.fakes.FakePermissionManager
import com.snabbit.runner.shared.features.awol.AWOL_BREACH_JSON
import com.snabbit.runner.shared.features.awol.awolEnvelope
import com.snabbit.runner.shared.features.awol.domain.AwolFlags
import com.snabbit.runner.shared.features.awol.domain.AwolPhase
import com.snabbit.runner.shared.features.job.FakeRunnerStateSource
import com.snabbit.runner.shared.features.job.domain.JobClock
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Coverage for [AwolViewModel]: every §9 routing-table row (incl. the PiP
 * rule), every episode rule (event_id keying, dismissed-resets-only-on-new-
 * event_id, phase-flip re-alert, server-clear), the launcher suppression
 * query ([AwolViewModel.isPhaseDismissed]), and the TR-03 countdown
 * (deadline − now, receipt fallback anchor, expiry → requestRefresh).
 */
class AwolViewModelTest {

    /** Deterministic clock whose `now` tracks the virtual test time. */
    private class MutableClock(var now: Long = 0L) : JobClock {
        override fun nowMillis(): Long = now
        override fun parseEpochMillis(iso: String): Long? = when (iso) {
            "2026-07-09T10:15:00+05:30" -> 900_000L
            "2026-07-09T10:00:00+05:30" -> 0L
            else -> null
        }
        override fun epochForLocalTimeToday(minutesOfDay: Int): Long = minutesOfDay * 60_000L
    }

    /** Counts [check] calls so tests can assert routing isn't re-evaluated per tick. */
    private class CountingPermissionManager(
        val delegate: FakePermissionManager = FakePermissionManager(),
    ) : PermissionManager by delegate {
        var checkCount = 0
            private set

        override suspend fun check(permission: SnabbitPermission): PermissionStatus {
            checkCount++
            return delegate.check(permission)
        }
    }

    private class Harness(testScope: TestScope) {
        val source = FakeRunnerStateSource()
        val clock = MutableClock()
        val permissions = CountingPermissionManager()
        val analytics = FakeAnalyticsTracker()

        /** Counts host alarm-silence calls (the `core/alarm` seam is Dart-backed in production). */
        var silenceCount = 0
            private set

        // Rides backgroundScope's Job so the coordinator's ticker is cancelled
        // when the test ends (its scope is process-lived in production).
        val viewModel = AwolViewModel(
            source = source,
            clock = clock,
            permissions = permissions,
            analytics = AwolAnalytics(analytics),
            logger = FakeLogger(),
            store = LocalizationStore(FakeLogger(), CrashReporter { _, _ -> }),
            scope = CoroutineScope(
                testScope.backgroundScope.coroutineContext +
                    UnconfinedTestDispatcher(testScope.testScheduler),
            ),
            silenceAlarm = { silenceCount++ },
        )

        fun grantOverlay() {
            permissions.delegate.statuses[SnabbitPermission.Overlay] = PermissionStatus.GRANTED
        }

        fun emitAwol(json: String) = source.emit(awolEnvelope(json))
    }

    // ── Routing row: snapshot == null ─────────────────────────────────────

    @Test
    fun noAwolKey_surfaceNone_everythingClears() = runTest {
        val h = Harness(this)
        assertEquals(AwolSurface.NONE, h.viewModel.uiState.value.surface)
        h.emitAwol(AWOL_BREACH_JSON)
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)

        h.source.emit(RunnerState(widgetName = "X", widgetData = null))
        val cleared = h.viewModel.uiState.value
        assertEquals(AwolSurface.NONE, cleared.surface)
        assertNull(cleared.snapshot)
    }

    // ── Routing row: foreground → overlay draws OVER the open app (show-both) ─

    @Test
    fun foreground_overlayGranted_routesOverlay_overOpenApp() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.viewModel.setHostVisibility(isForeground = true)
        h.emitAwol(AWOL_BREACH_JSON)
        // A safety alert must be unmissable: the overlay draws over the app even when
        // it's open. (The in-app pink card is the fallback when overlay isn't available.)
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)
    }

    @Test
    fun foreground_overlayUnavailable_routesHomeCard_fallback() = runTest {
        val h = Harness(this)
        // overlay NOT granted → the in-app pink card is the foreground fallback.
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.viewModel.setHostVisibility(isForeground = true)
        h.emitAwol(AWOL_BREACH_JSON)
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)
    }

    // ── Routing row: background + flag + permission → Overlay ─────────────

    @Test
    fun background_flagOn_permissionGranted_routesOverlay() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.viewModel.setHostVisibility(isForeground = false)
        h.emitAwol(AWOL_BREACH_JSON)
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)
    }

    // ── Routing row: backgrounded/locked + permission DENIED → still Overlay ─

    @Test
    fun background_permissionDenied_routesOverlay_keyguardAlertCase() = runTest {
        val h = Harness(this)
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.viewModel.setHostVisibility(isForeground = false)
        h.emitAwol(AWOL_BREACH_JSON)
        // Backgrounded/locked the presenting surface is either the keyguard alert
        // (needs NO overlay permission — routing NONE here self-finished it, B8)
        // or the launcher's window path, which independently gates canDrawOverlays
        // — so the missing grant must not block the OVERLAY route.
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)

        // Coming foreground re-routes: the draw-over DOES need the grant, so the
        // in-app pink card is the fallback (TR-06).
        h.viewModel.setHostVisibility(isForeground = true)
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)
    }

    // ── Routing row: permission check THROWS → degrade + log (TR-06) ──────

    @Test
    fun foreground_permissionCheckThrows_routesHomeCard_andLogsError() = runTest {
        val source = FakeRunnerStateSource()
        val logger = FakeLogger()
        val throwingPermissions = object : PermissionManager by FakePermissionManager() {
            override suspend fun check(permission: SnabbitPermission): PermissionStatus =
                throw IllegalStateException("permission subsystem unavailable")
        }
        val viewModel = AwolViewModel(
            source = source,
            clock = MutableClock(),
            permissions = throwingPermissions,
            analytics = AwolAnalytics(FakeAnalyticsTracker()),
            logger = logger,
            store = LocalizationStore(FakeLogger(), CrashReporter { _, _ -> }),
            scope = CoroutineScope(
                backgroundScope.coroutineContext +
                    UnconfinedTestDispatcher(testScheduler),
            ),
        )
        viewModel.setFlags(AwolFlags(overlayEnabled = true))
        viewModel.setHostVisibility(isForeground = true)
        source.emit(awolEnvelope(AWOL_BREACH_JSON))

        // overlayGranted() swallows the throw and treats the permission as
        // denied, so the foreground draw-over degrades to the pink card (TR-06)…
        assertEquals(AwolSurface.HOME_CARD, viewModel.uiState.value.surface)
        // …and the failure is logged, never silently eaten.
        assertTrue(
            logger.entries.any {
                it.level == FakeLogger.Level.ERROR &&
                    it.message.contains("overlay permission check failed") &&
                    it.throwable != null
            },
        )
    }

    // ── Routing row: flag off (ship dark, TR-07) ──────────────────────────

    @Test
    fun background_flagOff_routesNone_defaultFlagsAreDark() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setHostVisibility(isForeground = false)
        h.emitAwol(AWOL_BREACH_JSON)
        // No flags pushed at all → dark defaults → no overlay.
        assertEquals(AwolSurface.NONE, h.viewModel.uiState.value.surface)
    }

    // ── Routing row: PiP rule ─────────────────────────────────────────────

    @Test
    fun pip_routesHomeCard_notOverlay() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        // PiP: activity is STARTED not RESUMED → host reports not-foreground + pip.
        h.viewModel.setHostVisibility(isForeground = false, isInPip = true)
        h.emitAwol(AWOL_BREACH_JSON)
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)
    }

    // ── Acknowledgement silences the host alarm ───────────────────────────

    @Test
    fun dismiss_silencesTheHostAlarm() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.emitAwol(AWOL_BREACH_JSON)
        assertEquals(0, h.silenceCount)

        // "I Understand" must stop the breach alarm on the tap. Before this the
        // alarm's lifetime was bound only to server state, so an acknowledged
        // breach kept sounding for the rest of its repeat count.
        h.viewModel.onIntent(AwolUiIntent.Dismiss)
        assertEquals(1, h.silenceCount)
    }

    @Test
    fun showDirections_doesNotSilenceTheHostAlarm() = runTest {
        val h = Harness(this)
        h.emitAwol(AWOL_BREACH_JSON)
        // Directions is navigation, not acknowledgement — the runner is still out
        // of the hotspot and has not dismissed the alert.
        h.viewModel.onIntent(AwolUiIntent.ShowDirections)
        assertEquals(0, h.silenceCount)
    }

    // ── Episode rules (FR-05/06) ──────────────────────────────────────────

    @Test
    fun dismiss_closesOverlay_cardRemains_noReopenOnSameEpisodeRefresh() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.emitAwol(AWOL_BREACH_JSON)
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)

        // "I Understand" closes the overlay; in the foreground the pink card remains (show-both).
        h.viewModel.onIntent(AwolUiIntent.Dismiss)
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)

        // Same event_id, refreshed payload (e.g. red card count bump) → overlay stays
        // closed (FR-05 no-reopen); the card persists.
        h.emitAwol("""{"event_id": "evt-42", "state": "BREACH", "red_cards_total": 3}""")
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)
        // …and the data still updates underneath (FR-07: warning data persists).
        assertEquals(3, h.viewModel.uiState.value.snapshot?.redCardsTotal)
    }

    @Test
    fun dismissed_resetsOnNewEventIdOnly() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.emitAwol(AWOL_BREACH_JSON)
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)
        h.viewModel.onIntent(AwolUiIntent.Dismiss)
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)

        // New episode → dismissed memory resets, the overlay alert shows again.
        h.emitAwol("""{"event_id": "evt-43", "state": "BREACH"}""")
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)
    }

    @Test
    fun stateFlip_sameEpisode_alertsAgain() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.emitAwol("""{"event_id": "evt-42", "state": "BREACH"}""")
        h.viewModel.onIntent(AwolUiIntent.Dismiss)
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)

        // Breach ⇄ returned flip re-alerts once (FR-06) — dismissal is per (event, phase).
        h.emitAwol("""{"event_id": "evt-42", "state": "RE_ENTERED"}""")
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)
        assertEquals(AwolPhase.RE_ENTERED, h.viewModel.uiState.value.snapshot?.phase)
    }

    @Test
    fun missingEventId_derivedIdentity_dismissSticksAcrossRefresh() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.emitAwol("""{"state": "BREACH", "detected_at": "2026-07-09T10:00:00+05:30"}""")
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)
        h.viewModel.onIntent(AwolUiIntent.Dismiss)
        // Same derived episode (same detected_at) → overlay stays closed; card remains.
        h.emitAwol(
            """{"state": "BREACH", "detected_at": "2026-07-09T10:00:00+05:30", "red_cards_total": 1}""",
        )
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)
        // New detected_at → new derived episode → overlay re-alerts.
        h.emitAwol("""{"state": "BREACH", "detected_at": "2026-07-09T10:15:00+05:30"}""")
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)
    }

    @Test
    fun serverClear_endsEpisode_nextAppearanceAlertsAgain() = runTest {
        val h = Harness(this)
        h.emitAwol("""{"event_id": "evt-42"}""")
        h.viewModel.onIntent(AwolUiIntent.Dismiss)
        // Episode ends on server say-so…
        h.source.emit(RunnerState(widgetName = "X", widgetData = null))
        // …so the SAME event id reappearing is a fresh alert.
        h.emitAwol("""{"event_id": "evt-42"}""")
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)
    }

    // ── Launcher suppression query (isPhaseDismissed) ─────────────────────

    @Test
    fun isPhaseDismissed_trueAfterDismiss_forThatPhaseAndEpisodeOnly() = runTest {
        val h = Harness(this)
        h.emitAwol("""{"event_id": "evt-42", "state": "BREACH"}""")
        // Nothing dismissed yet → the launcher must not suppress the alert.
        assertFalse(h.viewModel.isPhaseDismissed(awolEnvelope("""{"event_id": "evt-42", "state": "BREACH"}""")))

        h.viewModel.onIntent(AwolUiIntent.Dismiss)
        // Same episode, same phase (payload refresh) → suppressed: no host-FGS
        // restart per store emission (FR-05 no-reopen, launcher-side)…
        assertTrue(h.viewModel.isPhaseDismissed(awolEnvelope("""{"event_id": "evt-42", "state": "BREACH", "red_cards_total": 2}""")))
        // …but a phase flip within the episode is a NEW alert (FR-06) — not suppressed…
        assertFalse(h.viewModel.isPhaseDismissed(awolEnvelope("""{"event_id": "evt-42", "state": "RE_ENTERED"}""")))
        // …and a new episode's emission is never pre-dismissed, even before the
        // collector has reset the dismissed memory for it (deterministic on the
        // emission + process memory — no coordinator race).
        assertFalse(h.viewModel.isPhaseDismissed(awolEnvelope("""{"event_id": "evt-43", "state": "BREACH"}""")))
    }

    @Test
    fun isPhaseDismissed_falseForNullAndPayloadFreeEmissions() = runTest {
        val h = Harness(this)
        h.emitAwol("""{"event_id": "evt-42", "state": "BREACH"}""")
        h.viewModel.onIntent(AwolUiIntent.Dismiss)
        // No payload → nothing to suppress (the spec wouldn't trigger anyway).
        assertFalse(h.viewModel.isPhaseDismissed(null))
        assertFalse(h.viewModel.isPhaseDismissed(RunnerState(widgetName = "X", widgetData = null)))
    }

    // ── Countdown (TR-03) ─────────────────────────────────────────────────

    @Test
    fun countdown_derivesFromServerDeadline_recomputedEachTick() = runTest {
        val h = Harness(this)
        h.clock.now = 0L
        // trigger_at parses to 900_000 → 900 s left.
        h.emitAwol(AWOL_BREACH_JSON)
        assertEquals(900, h.viewModel.uiState.value.remainingSeconds)

        h.clock.now = 10_000L
        advanceTimeBy(1_001)
        assertEquals(890, h.viewModel.uiState.value.remainingSeconds)
        assertFalse(h.viewModel.uiState.value.expired)
    }

    @Test
    fun countdown_missingTriggerAt_anchorsOnReceiptPlusRemaining() = runTest {
        val h = Harness(this)
        h.clock.now = 50_000L
        h.emitAwol("""{"event_id": "e", "countdown": {"remaining_seconds": 120}}""")
        assertEquals(120, h.viewModel.uiState.value.remainingSeconds)

        h.clock.now = 80_000L // 30 s later
        advanceTimeBy(1_001)
        assertEquals(90, h.viewModel.uiState.value.remainingSeconds)
    }

    @Test
    fun countdown_noAnchorAtAll_noMeter() = runTest {
        val h = Harness(this)
        h.emitAwol("""{"event_id": "e"}""")
        val state = h.viewModel.uiState.value
        assertNotNull(state.snapshot)
        assertNull(state.remainingSeconds)
        assertFalse(state.expired)
    }

    @Test
    fun countdown_expiry_clampsAtZero_andRequestsRefresh() = runTest {
        val h = Harness(this)
        h.clock.now = 0L
        h.emitAwol(AWOL_BREACH_JSON) // deadline at 900_000
        assertEquals(0, h.source.refreshCount)

        h.clock.now = 901_000L
        advanceTimeBy(1_001)
        val state = h.viewModel.uiState.value
        assertEquals(0, state.remainingSeconds)
        assertTrue(state.expired)
        assertEquals(1, h.source.refreshCount)

        // Warning persists (FR-07); the re-fetch is paced, not fired every tick.
        advanceTimeBy(3_000)
        assertEquals(1, h.source.refreshCount)
        assertEquals(AwolSurface.HOME_CARD, h.viewModel.uiState.value.surface)
    }

    @Test
    fun expiry_keepsAskingWhileTheServerStillReturnsTheExpiredAnchor() = runTest {
        val h = Harness(this)
        h.clock.now = 0L
        h.emitAwol(AWOL_BREACH_JSON) // deadline at 900_000
        h.clock.now = 901_000L
        advanceTimeBy(1_001)
        assertEquals(1, h.source.refreshCount)

        // The backend mints the next penalty cycle asynchronously, so the fetch
        // issued at zero comes back carrying the anchor that just expired. The
        // ticker is done and the anchor never moves, so a one-shot refresh left
        // the card frozen at 00:00 until a manual pull-to-refresh — keep asking.
        advanceTimeBy(5_000)
        assertEquals(2, h.source.refreshCount)
        advanceTimeBy(5_000)
        assertEquals(3, h.source.refreshCount)
    }

    @Test
    fun expiry_stopsAskingOnceTheNextCycleLands() = runTest {
        val h = Harness(this)
        h.clock.now = 0L
        h.emitAwol(AWOL_BREACH_JSON) // deadline at 900_000
        h.clock.now = 901_000L
        advanceTimeBy(1_001)
        advanceTimeBy(5_000)
        assertEquals(2, h.source.refreshCount)

        // Next cycle arrives → meter live again and the poll stands down.
        h.emitAwol("""{"event_id": "evt-42", "countdown": {"remaining_seconds": 60}}""")
        assertFalse(h.viewModel.uiState.value.expired)
        val settled = h.source.refreshCount
        advanceTimeBy(30_000)
        assertEquals(settled, h.source.refreshCount)
    }

    @Test
    fun expiry_stopsAskingWhenTheEpisodeClears() = runTest {
        val h = Harness(this)
        h.clock.now = 0L
        h.emitAwol(AWOL_BREACH_JSON)
        h.clock.now = 901_000L
        advanceTimeBy(1_001)
        assertEquals(1, h.source.refreshCount)

        // Server dropped the awol key (runner is back) — nothing left to wait for.
        h.source.emit(RunnerState(widgetName = "X", widgetData = null))
        advanceTimeBy(30_000)
        assertEquals(1, h.source.refreshCount)
    }

    @Test
    fun expiry_pollIsBounded_andPenaltyAnalyticsStaysOneShot() = runTest {
        val h = Harness(this)
        h.clock.now = 0L
        h.emitAwol(AWOL_BREACH_JSON)
        h.clock.now = 901_000L
        advanceTimeBy(1_001)

        // A server that never mints a new cycle must not leave it polling forever…
        advanceTimeBy(10 * 60_000L)
        assertEquals(12, h.source.refreshCount)
        // …and the penalty event stays one-per-anchor despite the repeated fetches.
        assertEquals(1, h.analytics.trackedNames.count { it == "awol_penalty_applied" })
    }

    @Test
    fun countdown_newAnchorAfterExpiry_allowsAnotherRefresh() = runTest {
        val h = Harness(this)
        h.clock.now = 0L
        h.emitAwol("""{"event_id": "e", "countdown": {"remaining_seconds": 1}}""")
        h.clock.now = 2_000L
        advanceTimeBy(1_001)
        assertEquals(1, h.source.refreshCount)

        // Server extends the deadline (new payload, new anchor) → meter live again…
        h.emitAwol("""{"event_id": "e", "countdown": {"remaining_seconds": 60}}""")
        assertFalse(h.viewModel.uiState.value.expired)
        // …and a later expiry can refresh again.
        h.clock.now = 63_000L
        advanceTimeBy(1_001)
        assertEquals(2, h.source.refreshCount)
    }

    @Test
    fun countdown_expiredDerivedAnchor_doesNotRearmRefresh() = runTest {
        val h = Harness(this)
        h.clock.now = 0L
        // No `trigger_at`, so the anchor is DERIVED as `now + remaining_seconds`
        // and therefore moves with every envelope. At remaining 0 — the normal
        // post-expiry steady state (FR-07: warning persists, meter static at
        // zero) — re-arming on any anchor change loops: expiry fires
        // requestRefresh() -> Dart re-fetches current_state -> new envelope ->
        // new derived anchor -> re-arm -> expiry fires again, unthrottled, for
        // the whole breach, also re-emitting awol_penalty_applied each time.
        h.emitAwol("""{"event_id": "e", "detected_at": "t", "countdown": {"remaining_seconds": 0}}""")
        assertEquals(1, h.source.refreshCount)

        // Each refresh brings another envelope back. `detected_at` varies so the
        // source's StateFlow actually re-emits (identical values are conflated);
        // the episode is still "e", so this is the same countdown throughout.
        repeat(3) { i ->
            h.clock.now += 1_000L
            h.emitAwol(
                """{"event_id": "e", "detected_at": "t$i", "countdown": {"remaining_seconds": 0}}""",
            )
        }
        assertEquals(1, h.source.refreshCount)
        assertEquals(1, h.analytics.trackedNames.count { it == "awol_penalty_applied" })
    }

    @Test
    fun meterExpiry_firesAwolPenaltyApplied() = runTest {
        val h = Harness(this)
        h.clock.now = 0L
        h.emitAwol("""{"event_id": "e", "countdown": {"remaining_seconds": 1}}""")
        h.clock.now = 2_000L
        advanceTimeBy(1_001)
        assertEquals(1, h.source.refreshCount)
        assertTrue("awol_penalty_applied" in h.analytics.trackedNames)
    }

    @Test
    fun countdownTicks_doNotReRouteOrRecheckPermission() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        h.viewModel.setHostVisibility(isForeground = false)
        h.clock.now = 0L
        h.emitAwol(AWOL_BREACH_JSON) // live 900 s anchor → ticker runs
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)

        val checksAfterRouting = h.permissions.checkCount
        h.clock.now = 5_000L
        advanceTimeBy(5_001) // five 1-Hz ticks
        // The meter recomputed…
        assertEquals(895, h.viewModel.uiState.value.remainingSeconds)
        // …but routing (and its permission check) did not re-run per tick.
        assertEquals(checksAfterRouting, h.permissions.checkCount)
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)
    }

    // ── Effects ───────────────────────────────────────────────────────────

    @Test
    fun showDirections_emitsOpenDirections_onlyWithCoordinates() = runTest {
        val h = Harness(this)
        val effects = mutableListOf<AwolEffect>()
        val job = launch(UnconfinedTestDispatcher(testScheduler)) {
            h.viewModel.effects.collect { effects.add(it) }
        }

        // No coordinates → CTA is a no-op (FR-04 gate).
        h.emitAwol("""{"event_id": "e", "hotspot": {"name": "HSR"}}""")
        h.viewModel.onIntent(AwolUiIntent.ShowDirections)
        assertTrue(effects.isEmpty())

        h.emitAwol(AWOL_BREACH_JSON)
        h.viewModel.onIntent(AwolUiIntent.ShowDirections)
        assertEquals(
            AwolEffect.OpenDirections(12.91, 77.64, "HSR Layout"),
            effects.single(),
        )
        job.cancel()
    }

    // ── Flags exposure ────────────────────────────────────────────────────

    @Test
    fun flags_hostPush_updatesRouting() = runTest {
        val h = Harness(this)
        h.grantOverlay()
        h.viewModel.setHostVisibility(isForeground = false)
        h.emitAwol(AWOL_BREACH_JSON)
        assertEquals(AwolSurface.NONE, h.viewModel.uiState.value.surface)

        // RC flips mid-session → Dart re-pushes → routing follows live.
        h.viewModel.setFlags(AwolFlags(overlayEnabled = true))
        assertEquals(AwolSurface.OVERLAY, h.viewModel.uiState.value.surface)
    }

    // ── Image resolution (server image_url ?: phase's RC fallback) ────────

    @Test
    fun imageUrl_serverPayloadWinsOverFallback() = runTest {
        val h = Harness(this)
        h.viewModel.setFlags(AwolFlags(fallbackBreachImageUrl = "https://cdn/enter.jpg"))
        h.emitAwol(AWOL_BREACH_JSON) // carries image_url
        assertEquals("https://img/map.png", h.viewModel.uiState.value.imageUrl)
    }

    @Test
    fun imageUrl_breachAndJobFallBackToEnterHotspot() = runTest {
        val h = Harness(this)
        h.viewModel.setFlags(
            AwolFlags(
                fallbackBreachImageUrl = "https://cdn/enter.jpg",
                fallbackReEnteredImageUrl = "https://cdn/back.png",
            ),
        )
        h.emitAwol("""{"event_id": "e", "state": "BREACH"}""")
        assertEquals("https://cdn/enter.jpg", h.viewModel.uiState.value.imageUrl)

        // JOB shares the enter-hotspot art (legacy `isBreach || isJob` rule).
        h.emitAwol("""{"event_id": "e2", "state": "JOB"}""")
        assertEquals("https://cdn/enter.jpg", h.viewModel.uiState.value.imageUrl)
    }

    @Test
    fun imageUrl_reEnteredFallsBackToBackInHotspot() = runTest {
        val h = Harness(this)
        h.viewModel.setFlags(
            AwolFlags(
                fallbackBreachImageUrl = "https://cdn/enter.jpg",
                fallbackReEnteredImageUrl = "https://cdn/back.png",
            ),
        )
        h.emitAwol("""{"event_id": "e", "state": "RE_ENTERED"}""")
        assertEquals("https://cdn/back.png", h.viewModel.uiState.value.imageUrl)
    }

    @Test
    fun imageUrl_noPayloadUrlNoFlags_staysNull_placeholderContract() = runTest {
        val h = Harness(this)
        h.emitAwol("""{"event_id": "e", "state": "BREACH"}""")
        assertNull(h.viewModel.uiState.value.imageUrl)
    }

    @Test
    fun imageUrl_lateFlagPush_resolvesLive() = runTest {
        val h = Harness(this)
        h.emitAwol("""{"event_id": "e", "state": "BREACH"}""")
        assertNull(h.viewModel.uiState.value.imageUrl)

        // RC assets land after the snapshot (startup ordering) → recompute
        // picks the fallback up without a new payload.
        h.viewModel.setFlags(AwolFlags(fallbackBreachImageUrl = "https://cdn/enter.jpg"))
        assertEquals("https://cdn/enter.jpg", h.viewModel.uiState.value.imageUrl)
    }
}

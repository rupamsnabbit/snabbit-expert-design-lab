package com.snabbit.runner.shared.features.shift.presentation.emergencylogout
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics
import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.periodleave.FakePeriodLeaveRepository
import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability
import com.snabbit.runner.shared.features.gamification.domain.model.NudgeLabel
import com.snabbit.runner.shared.features.gamification.domain.model.OutcomeStatus
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.shift.FakeShiftRepository
import com.snabbit.runner.shared.features.shift.core.domain.model.EmergencyLogoutAvailability
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class EmergencyLogoutViewModelTest {

    private data class Wired(
        val vm: EmergencyLogoutViewModel,
        val shift: FakeShiftRepository,
        val periodLeave: FakePeriodLeaveRepository,
        val analytics: FakeAnalyticsTracker,
    )

    private fun TestScope.wire(
        shift: FakeShiftRepository = FakeShiftRepository(),
        periodLeave: FakePeriodLeaveRepository = FakePeriodLeaveRepository(),
        onPostAction: (PostActionOutcome) -> Unit = {},
    ): Wired {
        val tracker = FakeAnalyticsTracker()
        return Wired(
            vm = EmergencyLogoutViewModel(
                shiftRepository = shift,
                periodLeaveRepository = periodLeave,
                analytics = EmergencyLogoutAnalytics(tracker),
                errorAnalytics = ErrorAnalytics(tracker),
                scope = backgroundScope,
                onPostAction = onPostAction,
            ),
            shift = shift,
            periodLeave = periodLeave,
            analytics = tracker,
        )
    }

    private fun waivedOutcome() = PostActionOutcome(
        status = OutcomeStatus.Waived,
        label = NudgeLabel.literal("Red card waived"),
        redCards = 1,
    )

    private fun TestScope.collectEffects(vm: EmergencyLogoutViewModel): MutableList<EmergencyLogoutUiEffect> {
        val sink = mutableListOf<EmergencyLogoutUiEffect>()
        backgroundScope.launch { vm.effects.collect { sink += it } }
        return sink
    }

    @Test fun load_success_populatesBothAvailabilities() = runTest {
        val w = wire(); runCurrent()
        val state = w.vm.uiState.value
        assertFalse(state.isLoading)
        assertEquals(1, state.availability?.remaining)
        assertEquals(1, state.periodLeave?.remaining)
        assertTrue(state.showPeriodLeaveRow)
        assertNull(state.errorType)
    }

    @Test fun load_failureOnEmergencyLogout_setsErrorMessage_andBlocksConfirm() = runTest {
        val shift = FakeShiftRepository().apply {
            enqueueEmergencyLogoutAvailability(Result.Err(RunnerActionError.Server))
        }
        val w = wire(shift = shift); runCurrent()
        val state = w.vm.uiState.value
        assertNull(state.availability)
        assertEquals(EmergencyLogoutError.Load, state.errorType)
        assertFalse(state.canConfirm)
    }

    @Test fun load_failureOnPeriodLeaveOnly_doesNotBlockSheet_andHidesRow() = runTest {
        val periodLeave = FakePeriodLeaveRepository().apply {
            enqueue(Result.Err(RunnerActionError.NoConnection))
        }
        val w = wire(periodLeave = periodLeave); runCurrent()
        val state = w.vm.uiState.value
        assertNotNull(state.availability)
        assertNull(state.periodLeave)
        assertFalse(state.showPeriodLeaveRow)
        assertNull(state.errorType)
        assertTrue(state.canConfirm)
    }

    @Test fun togglePeriodLeave_updatesEffectiveFlag() = runTest {
        val w = wire(); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.TogglePeriodLeave(checked = true)); runCurrent()
        assertTrue(w.vm.uiState.value.effectivePeriodLeave)
        w.vm.onIntent(EmergencyLogoutUiIntent.TogglePeriodLeave(checked = false)); runCurrent()
        assertFalse(w.vm.uiState.value.effectivePeriodLeave)
    }

    @Test fun togglePeriodLeave_whenRowHidden_isAlwaysIneffective() = runTest {
        // No period leave remaining → row hidden → effectivePeriodLeave must stay false
        // even if the toggle intent fires.
        val periodLeave = FakePeriodLeaveRepository().apply {
            enqueue(Result.Ok(PeriodLeaveAvailability(maxPeriodLeaves = 1, periodLeavesTaken = 1)))
        }
        val w = wire(periodLeave = periodLeave); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.TogglePeriodLeave(checked = true)); runCurrent()
        assertFalse(w.vm.uiState.value.effectivePeriodLeave)
    }

    @Test fun confirm_noPeriodLeave_postsFalse_emitsFinish() = runTest {
        val w = wire(); runCurrent()
        val effects = collectEffects(w.vm); runCurrent()

        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()

        assertEquals(1, w.shift.emergencyLogoutCalls.size)
        assertFalse(w.shift.emergencyLogoutCalls.single().periodLeave)
        assertEquals(EmergencyLogoutUiEffect.Finish, effects.single())
        assertTrue(w.vm.uiState.value.finished)
    }

    @Test fun confirm_withPeriodLeave_postsTrue_showsTakeCare_thenFinishOnAck() = runTest {
        val w = wire(); runCurrent()
        val effects = collectEffects(w.vm); runCurrent()

        w.vm.onIntent(EmergencyLogoutUiIntent.TogglePeriodLeave(checked = true)); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()

        // Period leave was selected → BE got true and TakeCare is up; no Finish yet.
        assertTrue(w.shift.emergencyLogoutCalls.single().periodLeave)
        assertTrue(w.vm.uiState.value.showTakeCare)
        assertTrue(effects.isEmpty())

        w.vm.onIntent(EmergencyLogoutUiIntent.AcknowledgeTakeCare); runCurrent()
        assertFalse(w.vm.uiState.value.showTakeCare)
        assertTrue(w.vm.uiState.value.finished)
        assertEquals(EmergencyLogoutUiEffect.Finish, effects.single())
    }

    @Test fun confirm_failure_setsErrorAndAllowsRetry() = runTest {
        val shift = FakeShiftRepository().apply {
            enqueueEmergencyLogout(Result.Err(RunnerActionError.Server))
        }
        val w = wire(shift = shift); runCurrent()
        val effects = collectEffects(w.vm); runCurrent()

        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()

        val state = w.vm.uiState.value
        assertFalse(state.isSubmitting)
        assertEquals(EmergencyLogoutError.Confirm, state.errorType)
        assertTrue(effects.isEmpty())
        // CTA must be re-enabled so the runner can retry.
        assertTrue(state.canConfirm)
    }

    @Test fun confirm_whileLoading_isIgnored() = runTest {
        val w = wire(); // no runCurrent() — still loading
        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()
        // Confirm guarded by canConfirm — no logout call should have fired.
        assertTrue(w.shift.emergencyLogoutCalls.isEmpty())
    }

    @Test fun dismiss_emitsFinishWithoutPosting() = runTest {
        val w = wire(); runCurrent()
        val effects = collectEffects(w.vm); runCurrent()

        w.vm.onIntent(EmergencyLogoutUiIntent.Dismiss); runCurrent()

        assertTrue(w.shift.emergencyLogoutCalls.isEmpty())
        assertEquals(EmergencyLogoutUiEffect.Finish, effects.single())
    }

    // ── post-action outcome sequencing (ECPO-753 follow-up) ────────────────

    @Test fun confirm_noPeriodLeave_deliversOutcomeAfterFinish() = runTest {
        val shift = FakeShiftRepository().apply {
            enqueueEmergencyLogout(Result.Ok(waivedOutcome()))
        }
        // The invariant: when the outcome reaches the host, `finished` is
        // already true (Finish emitted, sheet closing) — so the popup/waiver
        // never renders under the confirm sheet's popup window. Asserted from
        // inside the callback because the effects flow is collected async.
        var vmRef: EmergencyLogoutViewModel? = null
        var finishedAtDelivery: Boolean? = null
        val w = wire(
            shift = shift,
            onPostAction = { finishedAtDelivery = vmRef?.uiState?.value?.finished },
        )
        vmRef = w.vm
        runCurrent()

        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()

        assertEquals(true, finishedAtDelivery)
    }

    @Test fun confirm_withPeriodLeave_stashesOutcomeUntilTakeCareAck() = runTest {
        val shift = FakeShiftRepository().apply {
            enqueueEmergencyLogout(Result.Ok(waivedOutcome()))
        }
        val delivered = mutableListOf<PostActionOutcome>()
        val w = wire(shift = shift, onPostAction = { delivered += it }); runCurrent()

        w.vm.onIntent(EmergencyLogoutUiIntent.TogglePeriodLeave(checked = true)); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()

        // TakeCare is up — the outcome must NOT surface yet (it would render
        // under the TakeCare sheet and the waived red-card would be missed).
        assertTrue(w.vm.uiState.value.showTakeCare)
        assertTrue(delivered.isEmpty())

        w.vm.onIntent(EmergencyLogoutUiIntent.AcknowledgeTakeCare); runCurrent()
        assertEquals(1, delivered.single().redCards)

        // Stash is one-shot — a second ack must not re-present it.
        w.vm.onIntent(EmergencyLogoutUiIntent.AcknowledgeTakeCare); runCurrent()
        assertEquals(1, delivered.size)
    }

    @Test fun confirm_withPeriodLeave_nullOutcome_ackDeliversNothing() = runTest {
        var delivered = 0
        // Fake's default emergencyLogout response is Result.Ok(null) — no outcome.
        val w = wire(onPostAction = { delivered++ }); runCurrent()

        w.vm.onIntent(EmergencyLogoutUiIntent.TogglePeriodLeave(checked = true)); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.AcknowledgeTakeCare); runCurrent()

        assertEquals(0, delivered)
        assertTrue(w.vm.uiState.value.finished)
    }

    /**
     * Regression: `confirm()` read `canConfirm` synchronously but only raised
     * `isSubmitting` *inside* `scope.launch`. The real scope is a
     * `rememberCoroutineScope()` (AndroidUiDispatcher.Main — NOT Main.immediate), so the
     * body was deferred a frame and two taps both cleared the guard, firing two POSTs.
     * Emergency logout is destructive AND quota-limited, so a double-fire burns an
     * allowance the runner can't get back.
     *
     * No `runCurrent()` between the two intents — that's what makes them same-frame,
     * and `backgroundScope`'s StandardTestDispatcher defers the body exactly like the
     * real dispatcher does.
     */
    @Test fun confirm_tappedTwiceBeforeTheCoroutineRuns_postsOnlyOnce() = runTest {
        val w = wire(); runCurrent()

        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm)
        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm)
        runCurrent()

        assertEquals(1, w.shift.emergencyLogoutCalls.size)
    }

    // ── analytics ──────────────────────────────────────────────────────────

    @Test fun analytics_load_firesBsLoad() = runTest {
        val w = wire(); runCurrent()
        assertTrue("emergency_logout_bs_load" in w.analytics.trackedNames)
    }

    @Test fun analytics_confirm_noPeriodLeave_firesCtaAndConfirmedNone() = runTest {
        val w = wire(); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()
        assertTrue(
            w.analytics.trackedNames.containsAll(
                listOf("emergency_logout_bs_cta_click", "emergency_logout_confirmed"),
            ),
        )
        assertEquals(
            "none",
            w.analytics.events.last { it.name == "emergency_logout_confirmed" }.props["waiver_type"],
        )
    }

    @Test fun analytics_confirm_withPeriodLeave_confirmedPeriodLeave() = runTest {
        val w = wire(); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.TogglePeriodLeave(checked = true)); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()
        assertEquals(
            "period_leave",
            w.analytics.events.last { it.name == "emergency_logout_confirmed" }.props["waiver_type"],
        )
    }

    @Test fun analytics_waivedOutcome_firesWaiverLoad() = runTest {
        val shift = FakeShiftRepository().apply { enqueueEmergencyLogout(Result.Ok(waivedOutcome())) }
        val w = wire(shift = shift); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()
        assertTrue("emergency_logout_waiver_bs_load" in w.analytics.trackedNames)
    }

    // ── cross-cutting error events (X.3) ─────────────────────────────────────

    @Test fun analytics_loadFailure_firesErrorScreenLoadWithFlags() = runTest {
        val shift = FakeShiftRepository().apply {
            enqueueEmergencyLogoutAvailability(Result.Err(RunnerActionError.Server))
        }
        val w = wire(shift = shift); runCurrent()
        val load = w.analytics.events.single { it.name == "error_screen_load" }
        assertEquals("emergency_logout_load_failed", load.props["error_type"])
        assertEquals("bottomsheet", load.props["error_format"])
        assertEquals("emergency_logout", load.props["error_context"])
        assertEquals(true, load.props["retry_available"])
        // RunnerActionError.Server is not a connectivity error.
        assertEquals(false, load.props["is_network_error"])
    }

    @Test fun analytics_loadFailure_noConnection_setsNetworkFlag() = runTest {
        val shift = FakeShiftRepository().apply {
            enqueueEmergencyLogoutAvailability(Result.Err(RunnerActionError.NoConnection))
        }
        val w = wire(shift = shift); runCurrent()
        assertEquals(
            true,
            w.analytics.events.single { it.name == "error_screen_load" }.props["is_network_error"],
        )
    }

    @Test fun analytics_loadRetry_firesTryAgainCta_andDoesNotReFireLoad() = runTest {
        val shift = FakeShiftRepository().apply {
            enqueueEmergencyLogoutAvailability(Result.Err(RunnerActionError.Server))
            enqueueEmergencyLogoutAvailability(Result.Err(RunnerActionError.Server))
        }
        val w = wire(shift = shift); runCurrent()
        assertEquals(1, w.analytics.events.count { it.name == "error_screen_load" })

        // Retry from the load-failure error body re-dispatches Load.
        w.vm.onIntent(EmergencyLogoutUiIntent.Load); runCurrent()
        val cta = w.analytics.events.single { it.name == "error_screen_cta_click" }
        assertEquals("try_again", cta.props["cta_text"])
        assertEquals("emergency_logout_load_failed", cta.props["error_type"])
        assertEquals(1, cta.props["retry_attempt"])
        // A failed retry must NOT re-count the load — it stays at one.
        assertEquals(1, w.analytics.events.count { it.name == "error_screen_load" })
    }

    @Test fun analytics_confirmFailure_doesNotFireErrorScreenEvents() = runTest {
        // Confirm-failure is inline/transient (no dedicated CTA surface) → no cross-cutting error event.
        val shift = FakeShiftRepository().apply {
            enqueueEmergencyLogout(Result.Err(RunnerActionError.Server))
        }
        val w = wire(shift = shift); runCurrent()
        w.vm.onIntent(EmergencyLogoutUiIntent.Confirm); runCurrent()
        assertTrue("error_screen_load" !in w.analytics.trackedNames)
        assertTrue("error_screen_cta_click" !in w.analytics.trackedNames)
    }
}

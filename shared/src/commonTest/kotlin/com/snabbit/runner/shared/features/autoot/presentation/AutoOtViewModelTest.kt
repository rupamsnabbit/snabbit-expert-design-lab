package com.snabbit.runner.shared.features.autoot.presentation

import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.autoot.FakeAutoOtRepository
import com.snabbit.runner.shared.features.autoot.domain.AutoOtTrigger
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDenyReason
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails
import com.snabbit.runner.shared.features.autoot.domain.model.OtType
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.time.Duration.Companion.minutes

@OptIn(ExperimentalCoroutinesApi::class)
class AutoOtViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()
    private val repo = FakeAutoOtRepository()
    private val analytics = FakeAnalyticsTracker()
    private var refreshCount = 0
    private var consumedCount = 0

    @BeforeTest fun setUp() = Dispatchers.setMain(dispatcher)

    @AfterTest fun tearDown() = Dispatchers.resetMain()

    private fun offer(id: Int = 1, expiry: Int? = 5, otType: OtType = OtType.EndOt) = AutoOtDetails(
        requestId = id,
        otType = otType,
        regularShift = null,
        otShift = null,
        expiryDurationMinutes = expiry,
        status = null,
    )

    private fun vm(trigger: MutableStateFlow<AutoOtTrigger>) =
        AutoOtViewModel(
            trigger, repo, analytics,
            onPostAction = { refreshCount++ },
            onConsumed = { consumedCount++ },
        )

    @Test fun offer_showsOfferStep_andFiresPopupShown() = runTest(dispatcher) {
        val trigger = MutableStateFlow<AutoOtTrigger>(AutoOtTrigger.None)
        val vm = vm(trigger)
        trigger.value = AutoOtTrigger.Offer(offer()); runCurrent()

        assertEquals(AutoOtStep.Offer, vm.uiState.value.step)
        assertTrue("ot_popup_shown" in analytics.trackedNames)
    }

    @Test fun confirmThenSubmitOk_showsSuccess_refreshes_andFiresEvents() = runTest(dispatcher) {
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 7)))); runCurrent()

        vm.onIntent(AutoOtUiIntent.Confirm)
        assertEquals(AutoOtStep.Confirm, vm.uiState.value.step)

        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()
        assertEquals(AutoOtStep.Success, vm.uiState.value.step)
        assertEquals(listOf(7), repo.accepted)
        assertEquals(1, refreshCount)
        assertTrue(
            analytics.trackedNames.containsAll(listOf("ot_confirm_clicked", "ot_accept_clicked", "ot_success")),
        )
    }

    @Test fun submitError_showsFailure_withMappedError() = runTest(dispatcher) {
        repo.acceptResult = Result.Err(RunnerActionError.Server)
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer()))); runCurrent()

        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()

        assertEquals(AutoOtStep.Failure, vm.uiState.value.step)
        assertEquals(AppErrorType.SERVER_DOWN, vm.uiState.value.error)
    }

    @Test fun retryAfterFailure_reAccepts() = runTest(dispatcher) {
        repo.acceptResult = Result.Err(RunnerActionError.Server)
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 3)))); runCurrent()

        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()
        assertEquals(AutoOtStep.Failure, vm.uiState.value.step)

        repo.acceptResult = Result.Ok(Unit)
        vm.onIntent(AutoOtUiIntent.Retry); runCurrent()

        assertEquals(AutoOtStep.Success, vm.uiState.value.step)
        assertEquals(listOf(3, 3), repo.accepted)
    }

    // Dismissing the OFFER via the sheet ✕ IS the reject (the redesign dropped the in-body "Close"
    // button) → REJECTED + `ot_rejected`, preserving Flutter analytics parity.
    @Test fun dismissFromOffer_hides_rejectsRejected_andFiresEvent() = runTest(dispatcher) {
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 5)))); runCurrent()

        vm.onIntent(AutoOtUiIntent.Dismiss); runCurrent()

        assertNull(vm.uiState.value.step)
        assertEquals(listOf(5 to AutoOtDenyReason.REJECTED), repo.rejected)
        assertTrue("ot_rejected" in analytics.trackedNames)
        assertEquals(1, refreshCount) // Flutter refreshes current_state after a reject too
    }

    @Test fun dismissFromConfirm_rejectsDismissed_withNoRejectedEvent() = runTest(dispatcher) {
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 5)))); runCurrent()

        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Dismiss); runCurrent()

        assertNull(vm.uiState.value.step)
        assertEquals(listOf(5 to AutoOtDenyReason.DISMISSED), repo.rejected)
        assertFalse("ot_rejected" in analytics.trackedNames)
    }

    @Test fun preemptWhilePending_rejectsCancelled_andHides() = runTest(dispatcher) {
        val trigger = MutableStateFlow<AutoOtTrigger>(AutoOtTrigger.Offer(offer(id = 9)))
        val vm = vm(trigger); runCurrent()

        trigger.value = AutoOtTrigger.Preempt; runCurrent()

        assertNull(vm.uiState.value.step)
        assertEquals(listOf(9 to AutoOtDenyReason.CANCELLED_DUE_TO_JOB_ASSIGNMENT), repo.rejected)
    }

    @Test fun preemptAfterSuccess_isIgnored() = runTest(dispatcher) {
        val trigger = MutableStateFlow<AutoOtTrigger>(AutoOtTrigger.Offer(offer(id = 1)))
        val vm = vm(trigger); runCurrent()

        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()
        assertEquals(AutoOtStep.Success, vm.uiState.value.step)

        trigger.value = AutoOtTrigger.Preempt; runCurrent()
        assertEquals(AutoOtStep.Success, vm.uiState.value.step)
        assertTrue(repo.rejected.isEmpty())
    }

    @Test fun clearedTrigger_hidesPendingOffer_butKeepsSuccess() = runTest(dispatcher) {
        val trigger = MutableStateFlow<AutoOtTrigger>(AutoOtTrigger.Offer(offer(id = 1)))
        val vm = vm(trigger); runCurrent()

        // Pending offer + None (server rescinded) → hides.
        trigger.value = AutoOtTrigger.None; runCurrent()
        assertNull(vm.uiState.value.step)

        // New offer → accept → Success; a later None must NOT dismiss the success sheet.
        trigger.value = AutoOtTrigger.Offer(offer(id = 2)); runCurrent()
        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()
        assertEquals(AutoOtStep.Success, vm.uiState.value.step)

        trigger.value = AutoOtTrigger.None; runCurrent()
        assertEquals(AutoOtStep.Success, vm.uiState.value.step)
    }

    @Test fun expiry_flipsToExpired_andFiresEvent() = runTest(dispatcher) {
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 1, expiry = 5)))); runCurrent()
        assertEquals(AutoOtStep.Offer, vm.uiState.value.step)

        advanceTimeBy(6.minutes); runCurrent()

        assertEquals(AutoOtStep.Expired, vm.uiState.value.step)
        assertTrue("ot_expired" in analytics.trackedNames)
    }

    @Test fun cancelledTrigger_flipsActiveOfferToExpired_andFiresEvent() = runTest(dispatcher) {
        val trigger = MutableStateFlow<AutoOtTrigger>(AutoOtTrigger.Offer(offer(id = 1)))
        val vm = vm(trigger); runCurrent()
        assertEquals(AutoOtStep.Offer, vm.uiState.value.step)

        trigger.value = AutoOtTrigger.Cancelled; runCurrent()

        assertEquals(AutoOtStep.Expired, vm.uiState.value.step)
        assertTrue("ot_expired" in analytics.trackedNames)
    }

    @Test fun acknowledge_hidesTerminalSheet() = runTest(dispatcher) {
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 1, expiry = 5)))); runCurrent()
        advanceTimeBy(6.minutes); runCurrent()
        assertEquals(AutoOtStep.Expired, vm.uiState.value.step)

        vm.onIntent(AutoOtUiIntent.Acknowledge); runCurrent()
        assertNull(vm.uiState.value.step)
    }

    // Race guard: if the accept resolves AFTER the offer already expired mid-flight, stay Expired —
    // never flip to Success. `acceptGate` holds the accept in flight so the client timer can fire.
    @Test fun acceptResolvingAfterExpiry_staysExpired_neverSucceeds() = runTest(dispatcher) {
        val gate = CompletableDeferred<Unit>()
        repo.acceptGate = gate
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 8, expiry = 5)))); runCurrent()

        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()
        assertEquals(AutoOtStep.Loading, vm.uiState.value.step) // accept parked on the gate

        advanceTimeBy(6.minutes); runCurrent()
        assertEquals(AutoOtStep.Expired, vm.uiState.value.step) // client expiry fired mid-accept

        gate.complete(Unit); runCurrent() // accept now returns Ok
        assertEquals(AutoOtStep.Expired, vm.uiState.value.step) // guard held — did not flip
        assertFalse("ot_success" in analytics.trackedNames)
    }

    // Expiry guards: a null or non-positive expiry arms no timer — the offer stays live.
    @Test fun offerWithNullExpiry_neverAutoExpires() = runTest(dispatcher) {
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 1, expiry = null)))); runCurrent()
        assertEquals(AutoOtStep.Offer, vm.uiState.value.step)
        advanceTimeBy(60.minutes); runCurrent()
        assertEquals(AutoOtStep.Offer, vm.uiState.value.step)
    }

    @Test fun offerWithZeroExpiry_neverAutoExpires() = runTest(dispatcher) {
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 1, expiry = 0)))); runCurrent()
        assertEquals(AutoOtStep.Offer, vm.uiState.value.step)
        advanceTimeBy(60.minutes); runCurrent()
        assertEquals(AutoOtStep.Offer, vm.uiState.value.step)
    }

    // Consuming an offer (dismiss/reject here) notifies the coordinator so it resets its one-shot
    // trigger; a live offer must NOT be reported consumed.
    @Test fun dismiss_notifiesCoordinatorConsumed() = runTest(dispatcher) {
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 1)))); runCurrent()
        assertEquals(0, consumedCount)

        vm.onIntent(AutoOtUiIntent.Dismiss); runCurrent()
        assertNull(vm.uiState.value.step)
        assertTrue(consumedCount >= 1)
    }

    // ── cross-cutting error events (X.3) ─────────────────────────────────────

    @Test fun submitError_firesErrorScreenLoad_withFlags() = runTest(dispatcher) {
        repo.acceptResult = Result.Err(RunnerActionError.Server)
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer()))); runCurrent()
        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()

        val load = analytics.events.single { it.name == "error_screen_load" }
        assertEquals("auto_ot_failed", load.props["error_type"])
        assertEquals("bottomsheet", load.props["error_format"])
        assertEquals("overtime", load.props["error_context"])
        assertEquals(true, load.props["retry_available"])
        assertEquals(false, load.props["is_network_error"]) // Server → not a connectivity error
    }

    @Test fun submitError_noConnection_setsNetworkFlag() = runTest(dispatcher) {
        repo.acceptResult = Result.Err(RunnerActionError.NoConnection)
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer()))); runCurrent()
        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()
        assertEquals(
            true,
            analytics.events.single { it.name == "error_screen_load" }.props["is_network_error"],
        )
    }

    @Test fun retryFromFailure_firesTryAgainCta_andDoesNotReFireLoad() = runTest(dispatcher) {
        repo.acceptResult = Result.Err(RunnerActionError.Server)
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer(id = 3)))); runCurrent()
        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()
        assertEquals(1, analytics.events.count { it.name == "error_screen_load" })

        // Keep it failing so the re-entry proves the load isn't re-counted.
        vm.onIntent(AutoOtUiIntent.Retry); runCurrent()
        assertEquals(AutoOtStep.Failure, vm.uiState.value.step)
        val cta = analytics.events.single { it.name == "error_screen_cta_click" }
        assertEquals("try_again", cta.props["cta_text"])
        assertEquals("auto_ot_failed", cta.props["error_type"])
        assertEquals(1, cta.props["retry_attempt"])
        assertEquals(1, analytics.events.count { it.name == "error_screen_load" })
    }

    @Test fun dismissFromFailure_firesDismissCta_andHides() = runTest(dispatcher) {
        repo.acceptResult = Result.Err(RunnerActionError.Server)
        val vm = vm(MutableStateFlow(AutoOtTrigger.Offer(offer()))); runCurrent()
        vm.onIntent(AutoOtUiIntent.Confirm)
        vm.onIntent(AutoOtUiIntent.Submit); runCurrent()
        assertEquals(AutoOtStep.Failure, vm.uiState.value.step)

        vm.onIntent(AutoOtUiIntent.Dismiss); runCurrent()
        assertNull(vm.uiState.value.step)
        val cta = analytics.events.single { it.name == "error_screen_cta_click" }
        assertEquals("dismiss", cta.props["cta_text"])
        assertEquals("auto_ot_failed", cta.props["error_type"])
    }
}

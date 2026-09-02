package com.snabbit.runner.shared.features.job.presentation.checkin

import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.features.job.FakeJobActionRepository
import com.snabbit.runner.shared.features.job.FakeRunnerStateSource
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.JobMessage
import com.snabbit.runner.shared.features.job.domain.model.JobWidgetName
import com.snabbit.runner.shared.features.job.envelope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull

@OptIn(ExperimentalCoroutinesApi::class)
class CheckInViewModelTest {

    private fun TestScope.viewModel(
        source: FakeRunnerStateSource,
        actions: FakeJobActionRepository = FakeJobActionRepository(),
        analytics: JobAnalytics = JobAnalytics(FakeAnalyticsTracker()),
        silenceAlarm: () -> Unit = {},
    ): CheckInViewModel = CheckInViewModel(
        actions = actions,
        source = source,
        scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
        analytics = analytics,
        silenceAlarm = silenceAlarm,
    )

    private fun checkInSource() =
        FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, """{"job_id":739}"""))

    @Test
    fun open_opensAtOtpStep() = runTest {
        val vm = viewModel(checkInSource())
        assertNull(vm.uiState.value) // closed until opened

        vm.onIntent(CheckInUiIntent.Open)
        assertEquals(CheckInStep.Otp, vm.uiState.value?.step)
    }

    @Test
    fun open_silencesTheHostAlarm() = runTest {
        var silenced = 0
        val vm = viewModel(checkInSource(), silenceAlarm = { silenced++ })
        assertEquals(0, silenced)

        // Tapping Check In acts on the delayed-check-in prompt, so its alarm must
        // stop on the tap rather than running out its server-driven repeat count.
        vm.onIntent(CheckInUiIntent.Open)
        assertEquals(1, silenced)
    }

    @Test
    fun dismiss_doesNotSilenceTheHostAlarm() = runTest {
        var silenced = 0
        val vm = viewModel(checkInSource(), silenceAlarm = { silenced++ })
        vm.onIntent(CheckInUiIntent.Open)
        // Backing out of the sheet is not a second acknowledgement — only Open is.
        vm.onIntent(CheckInUiIntent.Dismiss)
        assertEquals(1, silenced)
    }

    @Test
    fun togglesBetweenOtpAndPhone() = runTest {
        val vm = viewModel(checkInSource())
        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.SwitchToPhone)
        assertEquals(CheckInStep.Phone, vm.uiState.value?.step)
        vm.onIntent(CheckInUiIntent.SwitchToOtp)
        assertEquals(CheckInStep.Otp, vm.uiState.value?.step)
    }

    @Test
    fun dismiss_clearsFlow() = runTest {
        val vm = viewModel(checkInSource())
        vm.onIntent(CheckInUiIntent.Open)
        assertNotNull(vm.uiState.value)
        vm.onIntent(CheckInUiIntent.Dismiss)
        assertNull(vm.uiState.value)
    }

    @Test
    fun startJob_success_advancesToSuccessStep_thenAckCloses() = runTest {
        val actions = FakeJobActionRepository()
        val source = checkInSource()
        val vm = viewModel(source, actions = actions)

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.StartJob("123"))
        advanceUntilIdle()

        val call = actions.startJobCalls.single()
        assertEquals(739, call.first)
        assertEquals("123", call.second)
        // Location is no longer fetched/sent on check-in (geofence intentionally dropped).
        assertNull(call.third)
        // 2xx morphs the sheet to its success step; the stage advance (refresh) is DEFERRED until
        // the success animation is acknowledged.
        assertEquals(CheckInStep.Success, vm.uiState.value?.step)
        assertFalse(vm.uiState.value?.isSubmitting ?: true)
        assertNull(vm.uiState.value?.errorMessage)
        assertEquals(0, source.refreshCount)

        // Progress animation done (or tapped) → close. Stage advance to IN_PROGRESS
        // now arrives via MQTT (WS5), so no current_state refresh.
        vm.onIntent(CheckInUiIntent.SuccessAcknowledged)
        advanceUntilIdle()
        assertEquals(0, source.refreshCount)
        assertNull(vm.uiState.value)
    }

    @Test
    fun startJob_genericFailure_setsGenericError_andDoesNotRefresh() = runTest {
        // An unclassified failure no longer claims a wrong OTP — it surfaces the generic copy. (A real
        // wrong OTP that carries a server message is shown verbatim via the Server branch.)
        val actions = FakeJobActionRepository(startJobError = JobActionError.Generic)
        val source = checkInSource()
        val vm = viewModel(source, actions = actions)

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.StartJob("999"))
        advanceUntilIdle()

        assertEquals(JobMessage.Generic, vm.uiState.value?.errorMessage)
        assertFalse(vm.uiState.value?.isSubmitting ?: true)
        assertEquals(0, source.refreshCount)
    }

    @Test
    fun startJob_networkFailure_setsNetworkError_notWrongOtp() = runTest {
        // ECPO-1059: a transport failure (correct OTP, poor connection) must read as the connectivity
        // copy, NOT the misleading "incorrect OTP".
        val actions = FakeJobActionRepository(startJobError = JobActionError.Network(AppErrorType.NO_INTERNET))
        val source = checkInSource()
        val vm = viewModel(source, actions = actions)

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.StartJob("123"))
        advanceUntilIdle()

        assertEquals(CheckInStep.Otp, vm.uiState.value?.step)
        assertEquals(JobMessage.NetworkError, vm.uiState.value?.errorMessage)
        assertFalse(vm.uiState.value?.isSubmitting ?: true)
        assertEquals(0, source.refreshCount)
    }

    @Test
    fun startJob_serverMessage_shownVerbatim() = runTest {
        // A genuinely wrong OTP arrives as a server CustomError and is shown verbatim (the message the
        // backend renders), never a hardcoded string.
        val actions = FakeJobActionRepository(startJobError = JobActionError.Server("Incorrect OTP"))
        val vm = viewModel(checkInSource(), actions = actions)

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.StartJob("123"))
        advanceUntilIdle()

        assertEquals(JobMessage.Server("Incorrect OTP"), vm.uiState.value?.errorMessage)
    }

    @Test
    fun startJob_failure_stampsErrorReasonOnCtaEvent() = runTest {
        // ECPO-1059: the check-in OTP CTA event must carry the coarse failure reason so a wrong OTP is
        // separable from a network drop in the funnel.
        val tracker = FakeAnalyticsTracker()
        val actions = FakeJobActionRepository(startJobError = JobActionError.Network(AppErrorType.NO_INTERNET))
        val vm = viewModel(checkInSource(), actions = actions, analytics = JobAnalytics(tracker))

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.StartJob("123"))
        advanceUntilIdle()

        val cta = tracker.events.last { it.name == "check_in_otp_bs_cta_click" }
        assertEquals("failed", cta.props["otp_verification_status"])
        assertEquals("network", cta.props["error_reason"])
    }

    @Test
    fun startJob_success_omitsErrorReasonOnCtaEvent() = runTest {
        val tracker = FakeAnalyticsTracker()
        val vm = viewModel(checkInSource(), analytics = JobAnalytics(tracker))

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.StartJob("123"))
        advanceUntilIdle()

        val cta = tracker.events.last { it.name == "check_in_otp_bs_cta_click" }
        assertEquals("success", cta.props["otp_verification_status"])
        // Sanitizer drops the null, so a successful attempt carries no error_reason.
        assertNull(cta.props["error_reason"])
    }

    @Test
    fun startJob_failure_409_setsReassignedMessage() = runTest {
        val vm = viewModel(checkInSource(), actions = FakeJobActionRepository(startJobError = JobActionError.Reassigned))

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.StartJob("123"))
        advanceUntilIdle()

        assertEquals(JobMessage.Reassigned, vm.uiState.value?.errorMessage)
    }

    @Test
    fun checkInWithPhone_success_advancesToSuccessStep_thenAckCloses() = runTest {
        val actions = FakeJobActionRepository()
        val source = checkInSource()
        val vm = viewModel(source, actions = actions)

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.SwitchToPhone)
        vm.onIntent(CheckInUiIntent.CheckInWithPhone("8606653178"))
        advanceUntilIdle()

        val call = actions.checkInWithoutOtpCalls.single()
        assertEquals(739, call.first)
        assertEquals("8606653178", call.second)
        // Location is no longer fetched/sent on check-in (geofence intentionally dropped).
        assertNull(call.third)
        assertEquals(CheckInStep.Success, vm.uiState.value?.step)
        assertEquals(0, source.refreshCount)

        // WS5: stage advance to IN_PROGRESS now arrives via MQTT — no current_state refresh.
        vm.onIntent(CheckInUiIntent.SuccessAcknowledged)
        advanceUntilIdle()
        assertEquals(0, source.refreshCount)
        assertNull(vm.uiState.value)
    }

    @Test
    fun checkInWithPhone_genericFailure_setsGenericError_andDoesNotRefresh() = runTest {
        // An unclassified failure is generic, not a "phone doesn't match" claim; the mismatch copy is
        // reserved for a real PHONE_NUMBER failure (see checkInWithPhone_phoneMismatchFailure below).
        val actions = FakeJobActionRepository(checkInWithoutOtpError = JobActionError.Generic)
        val source = checkInSource()
        val vm = viewModel(source, actions = actions)

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.SwitchToPhone)
        vm.onIntent(CheckInUiIntent.CheckInWithPhone("0000000000"))
        advanceUntilIdle()

        assertEquals(JobMessage.Generic, vm.uiState.value?.errorMessage)
        assertFalse(vm.uiState.value?.isSubmitting ?: true)
        assertEquals(0, source.refreshCount)
    }

    @Test
    fun checkInWithPhone_phoneMismatchFailure_setsPhoneMismatchError() = runTest {
        // A real PHONE_NUMBER failure_type reads as the phone-mismatch copy, inline on the phone step.
        val actions = FakeJobActionRepository(checkInWithoutOtpError = JobActionError.CheckInPhoneMismatch)
        val vm = viewModel(checkInSource(), actions = actions)

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.SwitchToPhone)
        vm.onIntent(CheckInUiIntent.CheckInWithPhone("0000000000"))
        advanceUntilIdle()

        assertEquals(CheckInStep.Phone, vm.uiState.value?.step)
        assertEquals(JobMessage.PhoneMismatch, vm.uiState.value?.errorMessage)
    }

    @Test
    fun checkInWithPhone_locationFailure_staysInlineOnPhoneStep() = runTest {
        // With no location sent a LOCATION reject isn't expected, but the defensive mapping must
        // surface the "not at the job location" copy inline — not a misleading phone-mismatch.
        val source = checkInSource()
        val vm = viewModel(source, actions = FakeJobActionRepository(checkInWithoutOtpError = JobActionError.CheckInLocation))

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.SwitchToPhone)
        vm.onIntent(CheckInUiIntent.CheckInWithPhone("8606653178"))
        advanceUntilIdle()

        assertEquals(CheckInStep.Phone, vm.uiState.value?.step)
        assertEquals(JobMessage.CheckInLocation, vm.uiState.value?.errorMessage)
        assertFalse(vm.uiState.value?.isSubmitting ?: true)
        assertEquals(0, source.refreshCount)
    }

    @Test
    fun startJob_locationFailure_staysInlineOnOtpStep() = runTest {
        // Same defensive mapping on the OTP path — the "not at the job location" copy, not a
        // misleading wrong-OTP.
        val actions = FakeJobActionRepository(startJobError = JobActionError.CheckInLocation)
        val vm = viewModel(checkInSource(), actions = actions)

        vm.onIntent(CheckInUiIntent.Open)
        vm.onIntent(CheckInUiIntent.StartJob("123"))
        advanceUntilIdle()

        assertEquals(CheckInStep.Otp, vm.uiState.value?.step)
        assertEquals(JobMessage.CheckInLocation, vm.uiState.value?.errorMessage)
    }

    @Test
    fun successAcknowledged_whenAlreadyClosed_isNoOp() = runTest {
        val source = checkInSource()
        val vm = viewModel(source)
        // No open flow → acknowledging is a no-op (idempotent "unless already closed").
        vm.onIntent(CheckInUiIntent.SuccessAcknowledged)
        advanceUntilIdle()
        assertEquals(0, source.refreshCount)
        assertNull(vm.uiState.value)
    }
}

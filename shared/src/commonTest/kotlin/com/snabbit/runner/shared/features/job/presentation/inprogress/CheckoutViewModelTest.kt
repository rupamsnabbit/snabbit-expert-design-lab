package com.snabbit.runner.shared.features.job.presentation.inprogress

import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.features.job.FakeJobActionRepository
import com.snabbit.runner.shared.features.job.FakeRunnerStateSource
import com.snabbit.runner.shared.features.job.IN_PROGRESS_JSON
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
import kotlin.test.assertNull

@OptIn(ExperimentalCoroutinesApi::class)
class CheckoutViewModelTest {

    private fun TestScope.viewModel(
        source: FakeRunnerStateSource,
        actions: FakeJobActionRepository = FakeJobActionRepository(),
        analytics: JobAnalytics = JobAnalytics(FakeAnalyticsTracker()),
    ): CheckoutViewModel = CheckoutViewModel(
        actions = actions,
        source = source,
        scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
        analytics = analytics,
    )

    private fun inProgressSource() =
        FakeRunnerStateSource(envelope(JobWidgetName.IN_PROGRESS, IN_PROGRESS_JSON))

    @Test
    fun open_noCampaign_opensAtOtp() = runTest {
        val vm = viewModel(inProgressSource())
        assertNull(vm.uiState.value) // closed until opened

        vm.onIntent(CheckoutUiIntent.Open(hasCampaign = false))
        assertEquals(CheckoutStep.Otp, vm.uiState.value?.step)
    }

    @Test
    fun open_withCampaign_opensAtCampaign_thenAdvancesToOtp() = runTest {
        val vm = viewModel(inProgressSource())

        vm.onIntent(CheckoutUiIntent.Open(hasCampaign = true))
        assertEquals(CheckoutStep.Campaign, vm.uiState.value?.step)

        vm.onIntent(CheckoutUiIntent.CampaignComplete)
        assertEquals(CheckoutStep.Otp, vm.uiState.value?.step)
    }

    @Test
    fun endJob_success_keepsSheetOpenSpinning_untilStageAdvances() = runTest {
        val actions = FakeJobActionRepository()
        val source = inProgressSource()
        val vm = viewModel(source, actions = actions)

        vm.onIntent(CheckoutUiIntent.Open(hasCampaign = false))

        // End Job submits check_out; on 2xx the sheet STAYS OPEN with the End Job button still spinning
        // (isSubmitting = true) — so the runner keeps getting feedback until the stage advances to
        // Completed, which unmounts the whole checkout sub-flow (closing the sheet). The advance arrives
        // via MQTT (WS5) with a feature-#4 timed fallback; no eager current_state refresh here.
        vm.onIntent(CheckoutUiIntent.EndJob("123"))
        advanceUntilIdle()
        assertEquals(listOf(739), actions.checkoutCalls)
        assertEquals(0, source.refreshCount)
        val flow = vm.uiState.value
        assertEquals(CheckoutStep.Otp, flow?.step)
        assertEquals(true, flow?.isSubmitting)
        assertNull(flow?.errorMessage)
    }

    @Test
    fun endJob_failure_staysOnOtp_withInlineError() = runTest {
        // ECPO-1059: an unclassified failure surfaces the generic copy, not a false "incorrect OTP" (a
        // real wrong OTP arrives as a server CustomError and is shown verbatim).
        val actions = FakeJobActionRepository(checkoutError = JobActionError.Generic)
        val vm = viewModel(inProgressSource(), actions = actions)

        vm.onIntent(CheckoutUiIntent.Open(hasCampaign = false))
        vm.onIntent(CheckoutUiIntent.EndJob("123"))
        advanceUntilIdle()

        val flow = vm.uiState.value
        assertEquals(CheckoutStep.Otp, flow?.step)
        assertEquals(JobMessage.Generic, flow?.errorMessage)
        assertFalse(flow?.isSubmitting ?: true)
    }

    @Test
    fun endJob_networkFailure_setsNetworkError_notWrongOtp() = runTest {
        // A transport failure (correct OTP, poor connection) reads as the connectivity copy.
        val actions = FakeJobActionRepository(checkoutError = JobActionError.Network(AppErrorType.NO_INTERNET))
        val vm = viewModel(inProgressSource(), actions = actions)

        vm.onIntent(CheckoutUiIntent.Open(hasCampaign = false))
        vm.onIntent(CheckoutUiIntent.EndJob("123"))
        advanceUntilIdle()

        val flow = vm.uiState.value
        assertEquals(CheckoutStep.Otp, flow?.step)
        assertEquals(JobMessage.NetworkError, flow?.errorMessage)
    }

    @Test
    fun dismiss_closesSheet() = runTest {
        val vm = viewModel(inProgressSource())
        vm.onIntent(CheckoutUiIntent.Open(hasCampaign = false))
        assertEquals(CheckoutStep.Otp, vm.uiState.value?.step)

        vm.onIntent(CheckoutUiIntent.Dismiss)
        assertNull(vm.uiState.value)
    }
}

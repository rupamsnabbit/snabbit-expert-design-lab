package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.data.JobSubmitAction
import com.snabbit.runner.shared.features.job.domain.model.JobCategory
import com.snabbit.runner.shared.features.job.domain.model.NewJobModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

/**
 * Unit tests for [JobInstrumentation]'s derived events. The accept-expiry timer — untestable while it
 * lived on [JobViewModel]'s `viewModelScope`/Main — is now driven with an injected test scope (the whole
 * point of the M1 extraction). Stage-load / `auto_checkout` behaviour is covered end-to-end through the VM
 * in `JobAnalyticsTest`.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class JobInstrumentationTest {

    @Test
    fun acceptExpiry_firesJobNotAccepted_whenTheOfferLapsesUnactioned() = runTest {
        val fake = FakeAnalyticsTracker()
        val state = MutableStateFlow<JobUiState>(newJob(remainingSeconds = 5, lossAmount = 50))
        instrumentation(fake).observe(state)

        assertFalse("job_not_accepted" in fake.trackedNames) // window still open
        advanceTimeBy(6_000)
        runCurrent()

        val e = fake.events.single { it.name == "job_not_accepted" }
        assertEquals(50, e.props["penalty_amount"])
    }

    @Test
    fun acceptExpiry_doesNotFire_whenTheOfferAdvancesBeforeExpiry() = runTest {
        val fake = FakeAnalyticsTracker()
        val state = MutableStateFlow<JobUiState>(newJob(remainingSeconds = 5, lossAmount = 50))
        instrumentation(fake).observe(state)

        // Runner accepts → the stage advances off NewJob before the window lapses.
        state.value = JobUiState.AwaitingCheckIn(jobId = 739)
        advanceTimeBy(6_000)
        runCurrent()

        assertFalse("job_not_accepted" in fake.trackedNames)
    }

    @Test
    fun acceptExpiry_doesNotFire_whileAnAcceptIsInFlight() = runTest {
        val fake = FakeAnalyticsTracker()
        val model = newJobModel(lossAmount = 50)
        val state = MutableStateFlow<JobUiState>(JobUiState.NewJob(model = model, acceptRemainingSeconds = 5))
        instrumentation(fake).observe(state)

        // Still NewJob at expiry, but an accept is in flight (shared JobActionStore) → not "not accepted".
        state.value = JobUiState.NewJob(model = model, acceptRemainingSeconds = 5, submittingAction = JobSubmitAction.Accept)
        advanceTimeBy(6_000)
        runCurrent()

        assertFalse("job_not_accepted" in fake.trackedNames)
    }

    private fun TestScope.instrumentation(fake: FakeAnalyticsTracker): JobInstrumentation =
        JobInstrumentation(
            analytics = JobAnalytics(fake),
            displayMode = "full_screen",
            scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
        )

    private fun newJobModel(lossAmount: Int?) = NewJobModel(
        jobId = 739,
        isDeniable = true,
        isLastHourJob = false,
        showDeallocationWarning = false,
        notifiedAtIso = null,
        timerDurationSec = 5,
        denyRate = null,
        lossAmount = lossAmount,
        address = null,
        geoAddress = null,
        isLongDistance = false,
        category = JobCategory.Expert,
        payout = null,
    )

    private fun newJob(remainingSeconds: Int, lossAmount: Int?) =
        JobUiState.NewJob(model = newJobModel(lossAmount), acceptRemainingSeconds = remainingSeconds)
}

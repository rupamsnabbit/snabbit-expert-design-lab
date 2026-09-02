package com.snabbit.runner.shared.features.job.presentation.completed.rating

import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.job.FakeJobActionRepository
import com.snabbit.runner.shared.features.job.FakeRunnerStateSource
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.data.NoLocationProvider
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class CustomerRatingViewModelTest {

    private fun TestScope.viewModel(
        dataSource: FakeJobActionRepository = FakeJobActionRepository(),
        source: FakeRunnerStateSource = FakeRunnerStateSource(),
        jobId: Int = 55,
        analytics: JobAnalytics = JobAnalytics(FakeAnalyticsTracker()),
    ): CustomerRatingViewModel = CustomerRatingViewModel(
        jobId = jobId,
        actions = dataSource,
        location = NoLocationProvider,
        source = source,
        appScope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
        analytics = analytics,
    )

    @Test
    fun select_setsRating_locally_withoutPosting() = runTest {
        // Selection is local-only — the POST is deferred to Submit ("Ready for next job") so it can't
        // advance the backend (and tear the Completed screen down) before the block flow runs.
        val dataSource = FakeJobActionRepository()
        val vm = viewModel(dataSource = dataSource)

        vm.onIntent(CustomerRatingUiIntent.SelectRating(4))

        assertEquals(4, vm.uiState.value.selectedRating)
        assertFalse(vm.uiState.value.isSubmitting)
        assertTrue(dataSource.rateCustomerCalls.isEmpty())
        assertFalse(vm.uiState.value.isError)
    }

    @Test
    fun reselect_updatesRating_stillWithoutPosting() = runTest {
        val dataSource = FakeJobActionRepository()
        val vm = viewModel(dataSource = dataSource)

        vm.onIntent(CustomerRatingUiIntent.SelectRating(2))
        vm.onIntent(CustomerRatingUiIntent.SelectRating(5))

        assertEquals(5, vm.uiState.value.selectedRating)
        assertTrue(dataSource.rateCustomerCalls.isEmpty())
    }

    @Test
    fun submit_postsSelectedRating_thenRefreshes() = runTest {
        val dataSource = FakeJobActionRepository()
        val source = FakeRunnerStateSource()
        val vm = viewModel(dataSource = dataSource, source = source)

        vm.onIntent(CustomerRatingUiIntent.SelectRating(4))
        vm.onIntent(CustomerRatingUiIntent.Submit)
        advanceUntilIdle()

        assertEquals(listOf(55 to 4), dataSource.rateCustomerCalls)
        assertEquals(1, source.refreshCount)
        assertFalse(vm.uiState.value.isError)
    }

    @Test
    fun submit_apiFailure_keepsSelection_setsError_andDoesNotRefresh() = runTest {
        val dataSource = FakeJobActionRepository(rateCustomerError = JobActionError.Generic)
        val source = FakeRunnerStateSource()
        val vm = viewModel(dataSource = dataSource, source = source)

        vm.onIntent(CustomerRatingUiIntent.SelectRating(1))
        vm.onIntent(CustomerRatingUiIntent.Submit)
        advanceUntilIdle()

        assertEquals(1, vm.uiState.value.selectedRating) // selection kept
        assertFalse(vm.uiState.value.isSubmitting)
        assertTrue(vm.uiState.value.isError)
        assertEquals(0, source.refreshCount)
    }

    @Test
    fun submit_withNoSelection_isNoOp() = runTest {
        val dataSource = FakeJobActionRepository()
        val source = FakeRunnerStateSource()
        val vm = viewModel(dataSource = dataSource, source = source)

        vm.onIntent(CustomerRatingUiIntent.Submit)
        advanceUntilIdle()

        assertTrue(dataSource.rateCustomerCalls.isEmpty())
        assertEquals(0, source.refreshCount)
    }
}

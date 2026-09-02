package com.snabbit.runner.shared.features.job.presentation.completed.housetasks

import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.job.FakeJobActionRepository
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.domain.model.HouseTask
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.storage.InMemoryPreferenceStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class HouseTasksViewModelTest {

    private fun TestScope.vm(
        actions: FakeJobActionRepository,
        analytics: FakeAnalyticsTracker,
    ) = HouseTasksViewModel(
        jobId = 739,
        actions = actions,
        preferenceStorage = InMemoryPreferenceStorage(),
        appScope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
        analytics = JobAnalytics(analytics),
        onSubmitted = {},
    )

    @Test fun fetchFailure_firesErrorScreenLoadOnce_withFlags() = runTest {
        val fake = FakeAnalyticsTracker()
        val actions = FakeJobActionRepository(fetchHouseTasksError = JobActionError.Generic)
        vm(actions, fake); advanceUntilIdle()

        val load = fake.events.single { it.name == "error_screen_load" }
        assertEquals("house_tasks_fetch_failed", load.props["error_type"])
        assertEquals("bottomsheet", load.props["error_format"])
        assertEquals("job_completed", load.props["error_context"])
        assertEquals(true, load.props["retry_available"])
        // JobActionError carries no no-connection variant → is_network_error is always false here.
        assertEquals(false, load.props["is_network_error"])
    }

    @Test fun retry_firesTryAgainCta_andDoesNotReFireLoad() = runTest {
        val fake = FakeAnalyticsTracker()
        val actions = FakeJobActionRepository(fetchHouseTasksError = JobActionError.Generic)
        val vm = vm(actions, fake); advanceUntilIdle()
        assertEquals(1, fake.events.count { it.name == "error_screen_load" })

        // "Try again" re-runs the fetch, which keeps failing — proving the load isn't re-counted.
        vm.onIntent(HouseTasksUiIntent.Retry); advanceUntilIdle()
        val cta = fake.events.single { it.name == "error_screen_cta_click" }
        assertEquals("try_again", cta.props["cta_text"])
        assertEquals("house_tasks_fetch_failed", cta.props["error_type"])
        assertEquals(1, cta.props["retry_attempt"])
        assertEquals(1, fake.events.count { it.name == "error_screen_load" })
    }

    @Test fun submitFailure_doesNotFireErrorScreenLoad() = runTest {
        // A submit failure keeps the grid up with an inline error — it is NOT a dedicated error surface,
        // so no cross-cutting error event fires (only the fetch-failure retry sheet does).
        val fake = FakeAnalyticsTracker()
        val actions = FakeJobActionRepository(
            houseTasks = listOf(HouseTask(key = "dishes", imageUrl = null)),
            submitHouseTasksError = JobActionError.Server("nope"),
        )
        val vm = vm(actions, fake); advanceUntilIdle()

        vm.onIntent(HouseTasksUiIntent.Toggle("dishes"))
        vm.onIntent(HouseTasksUiIntent.Submit); advanceUntilIdle()

        assertTrue("error_screen_load" !in fake.trackedNames)
        assertTrue("error_screen_cta_click" !in fake.trackedNames)
    }
}

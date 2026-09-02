package com.snabbit.runner.shared.features.home.seeyoutomorrow

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.home.seeyoutomorrow.data.SeeYouTomorrowProjector
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

@OptIn(ExperimentalCoroutinesApi::class)
class SeeYouTomorrowProjectorTest {

    private companion object {
        const val SEE_YOU_TOMORROW = """{"widget_name":"RUNNER_SEE_YOU_TOMORROW","widget_data":{}}"""
        const val OTHER = """{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{}}"""
    }

    /** Route the never-completing collect through backgroundScope. */
    private fun setup(scope: TestScope): Pair<RunnerStateStore, SeeYouTomorrowProjector> {
        val store = RunnerStateStore(FakeLogger())
        return store to SeeYouTomorrowProjector(store, scope.backgroundScope)
    }

    @Test fun nullEnvelope_isInactive() = runTest {
        val (_, rm) = setup(this); runCurrent()
        assertEquals(false, rm.active.value)
    }

    @Test fun otherWidget_isInactive() = runTest {
        val (store, rm) = setup(this)
        store.pushState(OTHER)
        runCurrent()
        assertEquals(false, rm.active.value)
    }

    @Test fun seeYouTomorrowWidget_isActive() = runTest {
        val (store, rm) = setup(this)
        store.pushState(SEE_YOU_TOMORROW)
        runCurrent()
        assertEquals(true, rm.active.value)
    }

    @Test fun leavingWidget_goesInactiveAgain() = runTest {
        val (store, rm) = setup(this)
        store.pushState(SEE_YOU_TOMORROW)
        runCurrent()
        assertEquals(true, rm.active.value)
        store.pushState(OTHER)
        runCurrent()
        assertEquals(false, rm.active.value)
    }
}

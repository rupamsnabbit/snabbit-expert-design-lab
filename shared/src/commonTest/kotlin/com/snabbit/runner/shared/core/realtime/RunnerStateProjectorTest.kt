package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class RunnerStateProjectorTest {

    private val jobEnvelope =
        """{"widget_name":"RUNNER_JOB_IN_PROGRESS","widget_data":{"job_id":650}}"""

    private fun applied(seq: Long, widgetJson: String) =
        AppliedSnapshot(epoch = 0, stateSeq = seq, widgetJson = widgetJson, source = SnapshotSource.MQTT)

    /** Cold boot: a row persisted before the projector starts must paint on subscribe. */
    @Test
    fun coldBoot_replaysPersistedSnapshot_onStart() = runTest {
        val store = InMemorySnapshotStore()
        store.applyIfNewer(applied(5, jobEnvelope)) // persisted BEFORE the projector runs
        val target = RunnerStateStore(FakeLogger())

        // Unconfined so the launched collector subscribes eagerly and processes the
        // replayed current value synchronously — no advanceUntilIdle race.
        val scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler))
        RunnerStateProjector(store, target).start(scope)

        assertEquals("RUNNER_JOB_IN_PROGRESS", target.snapshot()?.widgetName)
        scope.cancel()
    }

    /** Live: a snapshot applied after the projector is running projects through. */
    @Test
    fun liveUpdate_projectsNewlyAppliedSnapshot() = runTest {
        val store = InMemorySnapshotStore()
        val target = RunnerStateStore(FakeLogger())
        val scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler))
        RunnerStateProjector(store, target).start(scope)
        assertNull(target.snapshot()) // nothing persisted yet

        store.applyIfNewer(applied(1, jobEnvelope))

        assertEquals("RUNNER_JOB_IN_PROGRESS", target.snapshot()?.widgetName)
        scope.cancel()
    }

    /** A blank payload (widget-less snapshot) is skipped — never clobbers the read model. */
    @Test
    fun blankWidgetJson_isSkipped() = runTest {
        val store = InMemorySnapshotStore()
        val target = RunnerStateStore(FakeLogger())
        val scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler))
        RunnerStateProjector(store, target).start(scope)

        store.applyIfNewer(applied(1, ""))

        assertNull(target.snapshot())
        scope.cancel()
    }

    /** Later applied snapshots keep projecting — the read model tracks the store. */
    @Test
    fun subsequentSnapshots_keepProjecting() = runTest {
        val store = InMemorySnapshotStore()
        val target = RunnerStateStore(FakeLogger())
        val scope = CoroutineScope(UnconfinedTestDispatcher(testScheduler))
        RunnerStateProjector(store, target).start(scope)

        store.applyIfNewer(applied(1, jobEnvelope))
        assertEquals("RUNNER_JOB_IN_PROGRESS", target.snapshot()?.widgetName)

        store.applyIfNewer(applied(2, """{"widget_name":"RUNNER_POST_CHECKOUT","widget_data":{}}"""))
        assertEquals("RUNNER_POST_CHECKOUT", target.snapshot()?.widgetName)
        scope.cancel()
    }
}

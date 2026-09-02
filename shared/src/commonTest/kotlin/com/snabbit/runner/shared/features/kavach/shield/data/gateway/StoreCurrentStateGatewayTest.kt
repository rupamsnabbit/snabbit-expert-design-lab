package com.snabbit.runner.shared.features.kavach.shield.data.gateway

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.kavach.shield.data.store.JobIdCache
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class StoreCurrentStateGatewayTest {

    private fun store(json: String? = null) = RunnerStateStore(FakeLogger()).apply { json?.let(::pushState) }

    @Test
    fun presentJob_readsShieldSlice() = runTest {
        val store = store("""{"widget_name":"RUNNER_JOB_IN_PROGRESS","widget_data":{"job_id":650,"snabbit_shield_consent_enabled":true,"snabbit_shield_auto_enabled":true}}""")
        val snap = StoreCurrentStateGateway(store).snapshot()
        assertEquals(650, snap?.jobId)
        assertEquals(true, snap?.customerConsentEnabled)
        assertEquals(true, snap?.autoEnabled)
        assertEquals("RUNNER_JOB_IN_PROGRESS", snap?.widgetName)
    }

    @Test
    fun coldStore_isFailClosedNull() = runTest {
        val gw = StoreCurrentStateGateway(store())
        assertNull(gw.snapshot())            // nothing pushed yet → unavailable (fail-closed), not "no-job"
        assertNull(gw.currentJobId())
        assertEquals(false, gw.customerConsentEnabled())
    }

    @Test
    fun decodedNoJob_isNonNullSnapshotWithNullJobId() = runTest {
        val snap = StoreCurrentStateGateway(store("""{"widget_name":"HOME","widget_data":{}}""")).snapshot()
        assertEquals("HOME", snap?.widgetName)   // non-null snapshot proves this is "present, no-job"…
        assertNull(snap?.jobId)                   // …not a fetch failure (which would be a null snapshot)
        assertEquals(false, snap?.customerConsentEnabled)
    }

    @Test
    fun jobId_toleratesDoubleAndString() = runTest {
        assertEquals(650, StoreCurrentStateGateway(store("""{"widget_data":{"job_id":650.0}}""")).currentJobId())
        assertEquals(650, StoreCurrentStateGateway(store("""{"widget_data":{"job_id":"650"}}""")).currentJobId())
    }

    // ECPO-986: reads must never write the clip-attribution latch. `job_id` here survives
    // POST_ACCEPT/CHECK_IN/POST_CHECKOUT and lags the in-progress envelope, so an envelope-driven
    // write let a clip upload under the previous job. Only the arm sites may set it.
    @Test
    fun reads_neverTouchJobIdCache() = runTest {
        val cache = JobIdCache().apply { set(650) }   // job 650 armed and owns its clips
        // Envelope has already moved on to the NEXT job while 650's final clip is still being flushed.
        val gw = StoreCurrentStateGateway(store("""{"widget_name":"RUNNER_JOB_POST_ACCEPT","widget_data":{"job_id":651}}"""))
        gw.snapshot()
        gw.currentJobId()
        gw.widgetName()
        assertEquals(650, cache.get())
    }
}

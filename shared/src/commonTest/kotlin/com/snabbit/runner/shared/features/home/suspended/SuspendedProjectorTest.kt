package com.snabbit.runner.shared.features.home.suspended

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.home.suspended.data.SuspendedProjector
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import com.snabbit.runner.shared.features.profile.sampleRunnerProfile
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

@OptIn(ExperimentalCoroutinesApi::class)
class SuspendedProjectorTest {

    private companion object {
        const val SUSPENDED = """{"widget_name":"RUNNER_SUSPENDED","widget_data":{}}"""
        const val NOT_SUSPENDED = """{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{}}"""
    }

    /** Route the never-completing combined collect through backgroundScope. */
    private fun setup(
        scope: TestScope,
        profileStore: RunnerProfileStore = RunnerProfileStore(FakeLogger()),
    ): Pair<RunnerStateStore, SuspendedProjector> {
        val store = RunnerStateStore(FakeLogger())
        return store to SuspendedProjector(store, profileStore, scope.backgroundScope)
    }

    @Test fun nullEnvelope_yieldsNullInfo() = runTest {
        val (_, rm) = setup(this); runCurrent()
        assertNull(rm.info.value)
    }

    @Test fun nonSuspendedWidget_yieldsNullInfo() = runTest {
        val (store, rm) = setup(this)
        store.pushState(NOT_SUSPENDED)
        runCurrent()
        assertNull(rm.info.value)
    }

    @Test fun suspendedWidget_noProfile_flagsDefaultFalse() = runTest {
        val (store, rm) = setup(this)
        store.pushState(SUSPENDED)
        runCurrent()
        val info = assertNotNull(rm.info.value)
        assertEquals(false, info.isAadhaarRekyc)
        assertEquals(false, info.isRateCardV2Effective)
    }

    @Test fun suspendedWidget_readsFlagsFromProfile() = runTest {
        val profileStore = RunnerProfileStore(FakeLogger())
        profileStore.setProfile(
            sampleRunnerProfile(isAadhaarRekyc = true, isRateCardV2Effective = true),
        )
        val (store, rm) = setup(this, profileStore)
        store.pushState(SUSPENDED)
        runCurrent()
        val info = assertNotNull(rm.info.value)
        assertEquals(true, info.isAadhaarRekyc)
        assertEquals(true, info.isRateCardV2Effective)
    }

    @Test fun leavingSuspended_clearsInfo() = runTest {
        val (store, rm) = setup(this)
        store.pushState(SUSPENDED)
        runCurrent()
        assertNotNull(rm.info.value)
        store.pushState(NOT_SUSPENDED)
        runCurrent()
        assertNull(rm.info.value)
    }
}

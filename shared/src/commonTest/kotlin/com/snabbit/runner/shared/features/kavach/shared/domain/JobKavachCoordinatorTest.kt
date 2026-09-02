package com.snabbit.runner.shared.features.kavach.shared.domain

import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import com.snabbit.runner.shared.core.permissions.fakes.FakePermissionManager
import com.snabbit.runner.shared.features.job.FakeRunnerStateSource
import com.snabbit.runner.shared.features.job.IN_PROGRESS_JSON
import com.snabbit.runner.shared.features.job.NEW_JOB_JSON
import com.snabbit.runner.shared.features.job.POST_CHECKOUT_JSON
import com.snabbit.runner.shared.features.job.envelope
import com.snabbit.runner.shared.features.job.domain.model.JobWidgetName
import com.snabbit.runner.shared.features.kavach.FakeAppLifecycle
import com.snabbit.runner.shared.features.kavach.FakeSafetyDataSource
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionGate
import com.snabbit.runner.shared.core.realtime.RealtimeConfigStore
import com.snabbit.runner.shared.core.storage.EncryptedStore
import com.snabbit.runner.shared.core.FakeLogger
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class JobKavachCoordinatorTest {

    private val safety = FakeSafetyDataSource()
    private val source = FakeRunnerStateSource()
    private val perms = FakePermissionManager()
    private val lifecycle = FakeAppLifecycle(initial = true)

    private val analytics = FakeAnalyticsTracker()

    // RealtimeConfigStore seeded to the mqtt_config cohort (mqtt_kmp_enabled) so isKmpHosting() gates on it.
    private fun cohortConfig(kmpEnabled: Boolean = true) = RealtimeConfigStore(
        object : EncryptedStore {
            override suspend fun getString(key: String) = "{\"mqtt_kmp_enabled\":$kmpEnabled}".takeIf { key == "realtime.mqtt_config" }
            override suspend fun putString(key: String, value: String) = Unit
            override suspend fun delete(key: String) = Unit
            override suspend fun getAll(keys: Set<String>) = emptyMap<String, String>()
        },
        FakeLogger(),
    )

    private fun TestScope.build(cohort: RealtimeConfigStore? = cohortConfig()): JobKavachCoordinator {
        val dispatchers = testAppDispatchers(UnconfinedTestDispatcher(testScheduler))
        return JobKavachCoordinator(source, safety, KavachPermissionGate(perms), lifecycle, dispatchers, analytics, cohort)
    }

    private fun inProgress(jobId: Int = 739) =
        envelope(JobWidgetName.IN_PROGRESS, IN_PROGRESS_JSON.replace("\"job_id\": 739", "\"job_id\": $jobId"))

    private fun newJob() = envelope(JobWidgetName.NEW_JOB, NEW_JOB_JSON)
    private fun completed() = envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON)

    @Test
    fun entersInProgress_micGranted_launchesOnce() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        val c = build()
        source.emit(inProgress()); runCurrent()
        assertEquals(1, safety.startForJobCalls)
        assertFalse(c.micBlock.value)
        source.emit(inProgress()); runCurrent()   // same job re-polled → no second launch (edge-gated)
        assertEquals(1, safety.startForJobCalls)
    }

    @Test
    fun micDenied_suppressesLaunch_andBlocks() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.DENIED
        val c = build()
        source.emit(inProgress()); runCurrent()
        assertEquals(0, safety.startForJobCalls)   // mandatory mic → launch suppressed
        assertTrue(c.micBlock.value)
    }

    @Test
    fun micNeedsSettings_thenForegroundGrant_launches() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.DENIED_ALWAYS
        val c = build()
        source.emit(inProgress()); runCurrent()
        assertTrue(c.micBlock.value)
        assertEquals(1, perms.openSettingsCalls)   // permanently denied → routed to Settings
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        lifecycle.foregroundFlow.value = false; runCurrent()
        lifecycle.foregroundFlow.value = true; runCurrent()
        assertEquals(1, safety.startForJobCalls)
        assertFalse(c.micBlock.value)
    }

    @Test
    fun jobChange_relaunches() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        source.emit(inProgress(739)); runCurrent()
        source.emit(newJob()); runCurrent()   // leaves in-progress → resets edge (+ tears down)
        source.emit(inProgress(800)); runCurrent()
        assertEquals(2, safety.startForJobCalls)
    }

    @Test
    fun nonCohort_doesNotLaunchOrRetry() = runTest {
        // ECPO-933: a non-cohort runner must not arm — and must not enter the retry loop or fire the exhausted metric.
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        safety.startForJobArms = false                     // would drive retries if the gate let it through
        build(cohort = cohortConfig(kmpEnabled = false))
        source.emit(inProgress()); runCurrent(); advanceUntilIdle()
        assertEquals(0, safety.startForJobCalls)
        assertFalse(analytics.names().contains("expert_shield_arm_retry_exhausted"))
    }

    @Test
    fun notInProgress_doesNotLaunch() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        source.emit(newJob()); runCurrent()
        assertEquals(0, safety.startForJobCalls)
    }

    // ── teardown (job checkout / end) ──

    @Test
    fun leavingInProgress_afterLaunch_tearsDownOnce() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        source.emit(inProgress()); runCurrent()
        assertEquals(1, safety.startForJobCalls)
        source.emit(completed()); runCurrent()   // checkout OTP confirmed → Completed envelope
        assertEquals(1, safety.endForJobCalls)
    }

    @Test
    fun transientNullEnvelope_doesNotTearDown() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        source.emit(inProgress()); runCurrent()
        source.emit(null); runCurrent()   // envelope momentarily unloaded — must NOT tear down a live session
        assertEquals(0, safety.endForJobCalls)
    }

    @Test
    fun leavingInProgress_withoutLaunch_noTeardown() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        source.emit(newJob()); runCurrent()
        source.emit(completed()); runCurrent()
        assertEquals(0, safety.endForJobCalls)   // never launched → nothing to tear down
    }

    // ── induced-fix coverage: direct A→B teardown + startForJob retry-on-lag ──

    @Test
    fun directJobChange_tearsDownA_beforeLaunchingB() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        source.emit(inProgress(739)); runCurrent()   // launch A
        source.emit(inProgress(800)); runCurrent()   // DIRECT A→B (no idle between)
        assertEquals(2, safety.startForJobCalls)       // B launched
        assertEquals(1, safety.endForJobCalls)         // A torn down FIRST (the A→B fix; was 0 before)
    }

    // ── V4: teardown must not key on launchedJobId alone ──

    @Test
    fun armedWithoutLaunch_stillTearsDownOnLeaving() = runTest {
        // Manual "Activate Kavach" / ShieldLayerRestore call the plugin's onJobStarted() directly and
        // never set launchedJobId. Keying teardown on it alone skipped endForJob() for those sessions,
        // so the plugin's isJobActive stayed true for the rest of the process.
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        safety.shieldStateFlow.value = SafetyState.MONITORING   // armed by a non-coordinator path
        source.emit(completed()); runCurrent()
        assertEquals(1, safety.endForJobCalls)
    }

    @Test
    fun idleShieldWithoutLaunch_doesNotTearDown() = runTest {
        // Nothing armed → no spurious endForJob on every non-in-progress envelope.
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        source.emit(completed()); runCurrent()
        assertEquals(0, safety.endForJobCalls)
    }

    @Test
    fun joblessSos_isNotTornDownByStageChange() = runTest {
        // SOS is job-independent (contract §3) — a stage change must never kill a live one.
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        safety.shieldStateFlow.value = SafetyState.SOS_PENDING
        source.emit(completed()); runCurrent()
        assertEquals(0, safety.endForJobCalls)
    }

    @Test
    fun startForJobLags_thenClears_retriesUntilArmed() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        safety.startForJobArms = false                 // current_state jobId lags → startForJob no-ops
        build()
        source.emit(inProgress()); runCurrent()
        val firstCalls = safety.startForJobCalls
        assertTrue(firstCalls >= 1)                     // attempted at the launch edge
        safety.startForJobArms = true                  // lag clears
        advanceUntilIdle()                              // elapse the backoff → retry arms
        assertTrue(safety.startForJobCalls > firstCalls)
    }

    @Test
    fun startForJobExhaustsRetries_capsAtMax_andLeavesEdgeOpenForReArm() = runTest {
        // The lag never clears: all attempts no-op. The retry must cap at ARM_RETRY_MAX and, crucially,
        // NOT consume the launch edge — else the shield stays un-armed for the whole job with no recovery.
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        safety.startForJobArms = false
        build()
        source.emit(inProgress()); runCurrent()
        advanceUntilIdle()                              // elapse every backoff → retries exhaust
        val afterFirst = safety.startForJobCalls
        assertEquals(5, afterFirst)                     // capped at ARM_RETRY_MAX — no unbounded retry
        // Edge left open (launchedJobId never set on a failed arm): leaving then re-entering in-progress
        // for the same job re-attempts — instead of the burned-edge whole-job-unarmed bug. (The interposed
        // non-in-progress envelope defeats the state source's conflation so the re-entry actually delivers.)
        source.emit(newJob()); runCurrent()
        source.emit(inProgress()); runCurrent(); advanceUntilIdle()
        assertTrue(safety.startForJobCalls > afterFirst)
    }

    @Test
    fun startForJobExhaustsRetries_emitsTelemetry() = runTest {
        // #C1: the only signal that the lag outran the retry budget — matters more once MQTT lands.
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        safety.startForJobArms = false
        build()
        source.emit(inProgress()); runCurrent(); advanceUntilIdle()
        assertTrue(analytics.names().contains("expert_shield_arm_retry_exhausted"))
    }

    @Test
    fun startForJobArmsFirstTry_noExhaustionTelemetry() = runTest {
        perms.statuses[SnabbitPermission.Microphone] = PermissionStatus.GRANTED
        build()
        source.emit(inProgress()); runCurrent(); advanceUntilIdle()
        assertFalse(analytics.names().contains("expert_shield_arm_retry_exhausted"))
    }
}

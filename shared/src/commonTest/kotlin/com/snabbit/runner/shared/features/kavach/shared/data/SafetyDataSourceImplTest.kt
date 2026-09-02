package com.snabbit.runner.shared.features.kavach.shared.data

import com.safetykavach.shield.core.model.RecordingState
import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.core.config.DefaultRemoteConfigGateway
import com.snabbit.runner.shared.core.storage.InMemoryEncryptedStore
import com.snabbit.runner.shared.storage.InMemoryPreferenceStorage
import com.snabbit.runner.shared.features.job.domain.model.JobWidgetName
import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeBatteryMonitor
import com.snabbit.runner.shared.features.kavach.FakeModelAssetResolver
import com.snabbit.runner.shared.features.kavach.FakeStorageMonitor
import com.snabbit.runner.shared.features.kavach.FakeCurrentStateGateway
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeShieldConsentApi
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.FakeShieldProfileGateway
import com.snabbit.runner.shared.features.kavach.FakeSosApi
import com.snabbit.runner.shared.features.kavach.shield.data.store.JobIdCache
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldManualMonitoringStore
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldRcGates
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldMlLoadGuard
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTrigger
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTriggerHolder
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldInitLock
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SafetyDataSourceImplTest {

    private val shield = FakeShieldController()
    private val analytics = FakeAnalyticsTracker()
    private val consent = FakeShieldConsentApi()
    // Default to the in-progress widget: every arm test assumes a valid active job. The #V1 gate
    // now requires it, so the jobId-lag tests (jobId = null, widget still in-progress) keep exercising
    // the retry path, and the non-in-progress case gets its own test below.
    private val currentState = FakeCurrentStateGateway(widget = JobWidgetName.IN_PROGRESS)
    private val shieldProfile = FakeShieldProfileGateway()
    private val battery = FakeBatteryMonitor()
    private val storage = FakeStorageMonitor()
    private val manualStore = ShieldManualMonitoringStore(InMemoryEncryptedStore())

    // Live-RC cohort-gate stub: the listed keys resolve true, everything else to the caller's default.
    private fun rcGates(vararg on: String) =
        ShieldRcGates(FakeRemoteConfigGateway().apply { on.forEach { booleans[it] = true } })

    private val activeTrigger = ActiveTriggerHolder()
    // Empty store → mlAllowed() true, so ML-path tests behave as before (no prior crash).
    private val mlGuard = ShieldMlLoadGuard(InMemoryPreferenceStorage()) { "test" }

    private fun dataSourceWith(gates: ShieldRcGates, jobIdCache: JobIdCache = JobIdCache()) = SafetyDataSourceImpl(
        shield, DefaultRemoteConfigGateway(), FakeModelAssetResolver(), FakeSosApi(), consent, currentState, shieldProfile, manualStore, InMemoryPreferenceStorage(), battery, storage, analytics, gates, mlGuard, activeTrigger,
        jobIdCache = jobIdCache,
    )

    // Default: both kill-switches ON so the ladder tests exercise monitoring + recording.
    private val dataSource = dataSourceWith(rcGates("expert_shield_monitoring_only_enabled", "expert_shield_recording_enabled"))

    /** Seed the fully-enabled auto-start path (partner ∧ customer ∧ consent ∧ auto ∧ jobId). */
    private fun enableAutoStart() {
        shieldProfile.partnerEnabled = true
        shieldProfile.consentGiven = true    // runner consent now gates monitoring/recording (collected on home)
        currentState.customerConsent = true
        currentState.auto = true
        currentState.jobId = 650
    }

    private val fullLadder = listOf(
        "initialize", "onJobStarted", "startAccelerometerOnly",
        "startMonitoringOnly", "startRecording",
    )

    @Test
    fun activate_enabledConsented_runsFullLadder_withoutPostingConsent() = runTest {
        enableAutoStart()   // consent already given (home sheet) → arm never POSTs, just gates on the flag
        dataSource.activate()
        assertEquals(0, consent.calls)
        assertTrue(!analytics.names().contains("expert_shield_consent_given"))
        assertEquals(fullLadder, shield.calls)
    }

    @Test
    fun activate_present_autoOff_manualTapStillRecords() = runTest {
        enableAutoStart(); currentState.auto = false
        dataSource.activate()
        // activate() IS the manual "Activate Kavach" tap → enables BOTH mlMonitoring + recording
        // regardless of auto (contract §2 — recording = auto ∨ manualActivate).
        assertEquals(fullLadder, shield.calls)
    }

    @Test
    fun activate_present_persistsManualIntentKeyedToJob() = runTest {
        enableAutoStart(); currentState.auto = false
        dataSource.activate()
        // Manual recording intent persisted keyed by jobId so restore() re-records within this job (§2/§5).
        assertEquals(650, manualStore.activeJobId())
    }

    @Test
    fun activate_noJob_armsNothing() = runTest {
        enableAutoStart(); currentState.jobId = null
        dataSource.activate()
        // §1: no valid job → the shield layer is fully OFF, and the job-gate precedes the consent POST.
        assertTrue(shield.calls.isEmpty())
        assertEquals(0, consent.calls)
    }

    // ── startForJob() — automatic job-start (auto-gated recording, no manual persist) ──

    @Test
    fun startForJob_present_autoOn_runsFullLadder() = runTest {
        enableAutoStart()   // auto on
        dataSource.startForJob()
        assertEquals(fullLadder, shield.calls)
    }

    @Test
    fun startForJob_present_autoOff_stopsAtMonitoringOnly() = runTest {
        enableAutoStart(); currentState.auto = false
        dataSource.startForJob()
        // Auto path: auto off → monitoring-only, does NOT record (unlike the manual activate() tap).
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly", "startMonitoringOnly"), shield.calls)
    }

    @Test
    fun startForJob_autoOff_doesNotPersistManualIntent() = runTest {
        enableAutoStart(); currentState.auto = false
        dataSource.startForJob()
        assertNull(manualStore.activeJobId())   // auto path never persists a manual-record intent
    }

    @Test
    fun startForJob_noJob_armsNothing() = runTest {
        enableAutoStart(); currentState.jobId = null
        dataSource.startForJob()
        assertTrue(shield.calls.isEmpty())
        assertEquals(0, consent.calls)
    }

    // ── #V1 / #V6: arm must gate on the in-progress widget, not a bare jobId ──

    @Test
    fun arm_atPostAccept_withJobId_armsNothing() = runTest {
        // job_id survives POST_ACCEPT, so the old jobId-only gate armed the shield (FGS + recording of
        // the commute) before check-in. The widget gate blocks it.
        enableAutoStart(); currentState.widget = "RUNNER_JOB_POST_ACCEPT"   // jobId still 650
        assertEquals(false, dataSource.startForJob())
        assertTrue(shield.calls.isEmpty())
    }

    @Test
    fun arm_atPostCheckout_withJobId_armsNothing() = runTest {
        enableAutoStart(); currentState.widget = "RUNNER_POST_CHECKOUT"
        assertEquals(false, dataSource.startForJob())
        assertTrue(shield.calls.isEmpty())
    }

    // ── induced-fix coverage: startForJob():Boolean contract + endForJob stopped/trigger + arm stamp ──

    @Test
    fun startForJob_noJob_returnsFalse_forRetry() = runTest {
        enableAutoStart(); currentState.jobId = null
        assertEquals(false, dataSource.startForJob())   // jobId lag → no-op; JobKavachCoordinator retries on this
    }

    @Test
    fun startForJob_armed_returnsTrue_andStampsAutoTrigger() = runTest {
        enableAutoStart()
        assertEquals(true, dataSource.startForJob())              // armed
        assertEquals(ActiveTrigger.AUTO, activeTrigger.current)   // trigger stamped on the arm path (before start*)
    }

    @Test
    fun endForJob_whileRecording_firesStopped_andResetsTrigger() = runTest {
        enableAutoStart()
        dataSource.startForJob()                                     // arms → activeTrigger = AUTO
        shield.recordingStateFlow.value = RecordingState.RECORDING   // plugin now recording → mode=recording
        dataSource.endForJob()
        val stopped = analytics.last("expert_shield_stopped")
        assertNotNull(stopped)
        assertEquals("recording", stopped.props["mode"])
        assertEquals("job_ended", stopped.props["reason"])
        assertEquals("auto", stopped.props["trigger"])              // carried from the arm stamp
        assertNull(activeTrigger.current)                           // reset at job-end → no leak to next job
    }

    @Test
    fun sharedInitLock_serializesArm_whileHeld() = runTest {
        // The shared ShieldInitLock stops arm() and ShieldLayerRestore.restore() from double-initing on a
        // concurrent foreground cold-start-mid-job. Simulate restore() holding it: arm() must block until released.
        val lock = ShieldInitLock()
        val ds = SafetyDataSourceImpl(
            shield, DefaultRemoteConfigGateway(), FakeModelAssetResolver(), FakeSosApi(), consent, currentState,
            shieldProfile, manualStore, InMemoryPreferenceStorage(), battery, storage, analytics,
            rcGates("expert_shield_monitoring_only_enabled", "expert_shield_recording_enabled"), mlGuard, activeTrigger, lock,
            jobIdCache = JobIdCache(),
        )
        enableAutoStart()
        lock.mutex.lock()                                   // stand in for restore() holding the init lock
        val job = launch { ds.startForJob() }
        runCurrent()
        assertTrue(shield.calls.isEmpty())                  // blocked on the shared lock → no init yet
        lock.mutex.unlock()
        job.join()
        assertTrue(shield.calls.contains("initialize"))     // proceeds once released
    }

    @Test
    fun startForJob_currentStateFetchFails_throws() = runTest {
        enableAutoStart(); currentState.snapshotFails = true
        assertFailsWith<IllegalStateException> { dataSource.startForJob() }   // fail-closed (§1)
        assertTrue(shield.calls.isEmpty())
    }

    @Test
    fun activate_currentStateFetchFails_throws_andArmsNothing() = runTest {
        enableAutoStart(); currentState.snapshotFails = true   // current_state fetch failure
        assertFailsWith<IllegalStateException> { dataSource.activate() }   // fail-closed → retryable error (§1)
        assertTrue(shield.calls.isEmpty())
        assertTrue(analytics.names().contains("expert_shield_error"))
    }

    @Test
    fun activate_notEnabled_reachesAccelerometerOnly() = runTest {
        shieldProfile.partnerEnabled = false; currentState.customerConsent = true   // present = false
        currentState.auto = true; currentState.jobId = 650
        dataSource.activate()
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly"), shield.calls)
        val degraded = analytics.last("expert_shield_degraded_mode_active")
        assertNotNull(degraded)
        assertEquals("not_enabled", degraded.props["reason"])
        assertEquals("accelerometer_only", degraded.props["mode"])
    }

    @Test
    fun activate_whenShieldAlreadyActive_skipsInit_idempotent() = runTest {
        enableAutoStart()
        shield.shieldStateFlow.value = SafetyState.MONITORING   // already active (restart / re-activate)
        dataSource.activate()
        assertTrue(!shield.calls.contains("initialize"))        // §16 idempotent — no re-init
        assertTrue(!shield.calls.contains("onJobStarted"))
        assertTrue(shield.calls.contains("startRecording"))     // layer commands still issued (plugin no-ops)
    }

    @Test
    fun activate_notConsented_reachesAccelerometerOnly() = runTest {
        enableAutoStart(); shieldProfile.consentGiven = null   // consent not given → ML/recording gated off
        dataSource.activate()
        // Floor only: accelerometer + SOS always run; monitoring/recording wait on runner consent (home sheet).
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly"), shield.calls)
        assertEquals(0, consent.calls)   // arm never POSTs — consent is a home-sheet concern now
        val degraded = analytics.last("expert_shield_degraded_mode_active")
        assertNotNull(degraded)
        assertEquals("no_runner_consent", degraded.props["reason"])
        assertEquals("accelerometer_only", degraded.props["mode"])
    }

    @Test
    fun activate_monitoringRcOff_reachesAccelerometerOnly() = runTest {
        enableAutoStart()   // partner ∧ customer ∧ consent ∧ auto — but the RC cohort kill-switch is OFF
        dataSourceWith(rcGates()).activate()   // both cohort flags default OFF
        // RC gate closed → ML/recording never start; only the accelerometer + SOS floor.
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly"), shield.calls)
        val degraded = analytics.last("expert_shield_degraded_mode_active")
        assertNotNull(degraded)
        assertEquals("rc_monitoring_off", degraded.props["reason"])
        assertEquals("accelerometer_only", degraded.props["mode"])
    }

    @Test
    fun activate_recordingRcOff_stopsAtMonitoringOnly() = runTest {
        enableAutoStart()   // fully enabled, auto on
        // monitoring cohort ON, recording cohort OFF → monitoring-only, no recording (even on the manual tap).
        dataSourceWith(rcGates("expert_shield_monitoring_only_enabled")).activate()
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly", "startMonitoringOnly"), shield.calls)
    }

    @Test
    fun triggerSos_delegatesToTriggerManualSoS() = runTest {
        dataSource.triggerSos()
        assertEquals(listOf("triggerManualSoS"), shield.calls)
    }

    @Test
    fun endSos_delegatesToDeescalate() = runTest {
        dataSource.endSos()
        assertEquals(listOf("deescalateSoS"), shield.calls)
    }

    @Test
    fun arm_whenMlGuardBlocks_emitsMlDisabledEvent_andStillArmsFloor() = runTest {
        // A prior native ML load-crash left a pending marker for THIS build → guard blocks ML. Recording/
        // accelerometer/SOS still arm per RC; the suppressed cohort is surfaced via analytics.
        val guard = ShieldMlLoadGuard(InMemoryPreferenceStorage()) { "v1" }
        guard.beginAttempt()   // marker survives (never cleared) → mlAllowed() == false for "v1"
        val ds = SafetyDataSourceImpl(
            shield, DefaultRemoteConfigGateway(), FakeModelAssetResolver(), FakeSosApi(), consent, currentState,
            shieldProfile, manualStore, InMemoryPreferenceStorage(), battery, storage, analytics,
            rcGates("expert_shield_monitoring_only_enabled", "expert_shield_recording_enabled"), guard, activeTrigger,
            jobIdCache = JobIdCache(),
        )
        enableAutoStart()
        ds.startForJob()
        assertTrue(analytics.names().contains("expert_shield_ml_disabled_after_crash"))
        assertTrue(shield.calls.contains("startAccelerometerOnly"))   // floor still armed despite ML block
    }

    @Test
    fun callSosTeam_dialsWithRcFallbackPhone() = runTest {
        val rc = FakeRemoteConfigGateway().apply { strings["expert_shield_sos_fallback_phone"] = "555" }
        val sos = FakeSosApi()
        SafetyDataSourceImpl(shield, rc, FakeModelAssetResolver(), sos, consent, currentState, shieldProfile, manualStore, InMemoryPreferenceStorage(), battery, storage, analytics, rcGates(), mlGuard, jobIdCache = JobIdCache()).callSosTeam()
        assertEquals(1, sos.callSosTeamCalls)
        assertEquals("555", sos.lastCallPhone)
    }

    @Test
    fun conditions_batteryBelowThreshold_emitsBatteryLow() = runTest {
        battery.flow.value = 14   // < default 15
        storage.flow.value = 2000
        assertEquals(SafetyCondition.BATTERY_LOW, dataSource.conditions().first())
    }

    @Test
    fun conditions_storageBelowThreshold_takesPrecedenceOverBattery() = runTest {
        battery.flow.value = 14
        storage.flow.value = 499   // < default 500 → storage wins
        assertEquals(SafetyCondition.NO_STORAGE, dataSource.conditions().first())
    }

    @Test
    fun conditions_nullReadings_failOpenToNone() = runTest {
        battery.flow.value = null
        storage.flow.value = null
        assertEquals(SafetyCondition.NONE, dataSource.conditions().first())
    }

    @Test
    fun conditions_healthy_emitsNone() = runTest {
        battery.flow.value = 80
        storage.flow.value = 2000
        assertEquals(SafetyCondition.NONE, dataSource.conditions().first())
    }

    @Test
    fun activate_onFailure_reportsShieldError_andRethrows() = runTest {
        enableAutoStart()
        shield.failOnInitialize = RuntimeException("boom")
        assertFailsWith<RuntimeException> { dataSource.activate() }  // IG-08: rethrow → VM error state
        assertTrue(analytics.names().contains("expert_shield_error"))
        assertEquals("boom", analytics.last("expert_shield_error")?.props?.get("error_message"))
    }

    @Test
    fun state_mirrorsThePlugin() = runTest {
        assertEquals(shield.shieldState, dataSource.shieldState)
        assertEquals(shield.recordingState, dataSource.recordingState)
        assertEquals(shield.monitoringState, dataSource.monitoringState)
    }

    // ECPO-986: the upload seam reads JobIdCache to stamp booking_id on every clip, so the latch must
    // change ONLY on a successful arm. Previously it tracked whatever job_id the last envelope read
    // carried, which lags the in-progress edge — clips uploaded under the previous job.
    @Test
    fun jobIdLatch_survivesTheArmLagWindow_andFlipsOnlyOnASuccessfulArm() = runTest {
        val cache = JobIdCache()
        val ds = dataSourceWith(
            rcGates("expert_shield_monitoring_only_enabled", "expert_shield_recording_enabled"),
            cache,
        )

        enableAutoStart()                        // job 650 in progress
        assertTrue(ds.startForJob())
        assertEquals(650, cache.get())           // 650 owns its clips

        // 650 checked out, 651 is in progress, but current_state's job_id hasn't caught up yet — the
        // documented lag that makes startForJob() return false and JobKavachCoordinator retry.
        currentState.jobId = null
        assertTrue(!ds.startForJob())
        assertEquals(650, cache.get())           // a clip flushed here still belongs to 650, not null/651

        currentState.jobId = 651                 // envelope caught up → arm succeeds → 651 takes ownership
        assertTrue(ds.startForJob())
        assertEquals(651, cache.get())
    }

    // Kill-switch: the gates the host pushes must mirror the tier decisions, so the engine can refuse
    // monitoring/recording/ML on every path (incl. its own SOS auto-arm) instead of latching them on.
    @Test
    fun arm_pushesGatesMatchingTheTierDecisions() = runTest {
        enableAutoStart()
        dataSource.startForJob()
        val g = shield.lastGates
        assertNotNull(g)
        assertTrue(g.monitoring)          // consent + partner/customer + RC monitoring on
        assertTrue(g.recording)           // RC recording on
        assertTrue(!g.ml)                 // expert_shield_ml_detection_enabled defaults OFF
    }

    @Test
    fun arm_withoutConsent_pushesClosedMonitoringAndRecordingGates() = runTest {
        enableAutoStart(); shieldProfile.consentGiven = false
        dataSource.startForJob()
        val g = shield.lastGates
        assertNotNull(g)
        assertTrue(!g.monitoring)
        assertTrue(!g.recording)
    }

    // ECPO-986 (plugin side): the arm site hands the job down so the plugin can stamp it on every clip.
    @Test
    fun arm_handsTheJobIdToThePlugin() = runTest {
        enableAutoStart()
        dataSource.startForJob()
        assertEquals(650, shield.startedJobId)
    }
}

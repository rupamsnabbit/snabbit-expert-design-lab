package com.snabbit.runner.shared.features.kavach.shield.domain.restore

import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.core.storage.InMemoryEncryptedStore
import com.snabbit.runner.shared.storage.InMemoryPreferenceStorage
import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.shield.data.store.JobIdCache
import com.snabbit.runner.shared.features.kavach.FakeCurrentStateGateway
import com.snabbit.runner.shared.features.kavach.FakeModelAssetResolver
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.FakeShieldProfileGateway
import com.snabbit.runner.shared.core.realtime.RealtimeConfigStore
import com.snabbit.runner.shared.core.storage.EncryptedStore
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldManualMonitoringStore
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldInitLock
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldMlLoadGuard
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldRcGates
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ShieldLayerRestoreTest {

    private val shield = FakeShieldController()
    private val currentState = FakeCurrentStateGateway(jobId = 650, widget = "RUNNER_JOB_IN_PROGRESS")
    private val profile = FakeShieldProfileGateway()
    private val rc = FakeRemoteConfigGateway()
    private val manual = ShieldManualMonitoringStore(InMemoryEncryptedStore())
    private val realtimeConfig = cohortConfig()

    // RealtimeConfigStore seeded to the mqtt_config cohort so isKmpHosting() gates on it.
    private fun cohortConfig(kmpEnabled: Boolean = true) = RealtimeConfigStore(
        object : EncryptedStore {
            override suspend fun getString(key: String) = "{\"mqtt_kmp_enabled\":$kmpEnabled}".takeIf { key == "realtime.mqtt_config" }
            override suspend fun putString(key: String, value: String) = Unit
            override suspend fun delete(key: String) = Unit
            override suspend fun getAll(keys: Set<String>) = emptyMap<String, String>()
        },
        FakeLogger(),
    )

    // Live-RC cohort-gate stub: listed keys resolve true, else the caller default (OFF).
    private fun rcGates(vararg on: String) =
        ShieldRcGates(FakeRemoteConfigGateway().apply { on.forEach { booleans[it] = true } })

    // Default: both kill-switches ON so the ladder tests exercise monitoring + recording.
    private fun restore(gates: ShieldRcGates = rcGates("expert_shield_monitoring_only_enabled", "expert_shield_recording_enabled"), cohort: RealtimeConfigStore = realtimeConfig) =
        ShieldLayerRestore(shield, currentState, profile, manual, rc, FakeModelAssetResolver(), gates, FakeAnalyticsTracker(), ShieldInitLock(), ShieldMlLoadGuard(InMemoryPreferenceStorage()) { "test" }, cohort, jobIdCache = JobIdCache())

    private val fullLadder = listOf(
        "initialize", "onJobStarted", "startAccelerometerOnly", "startMonitoringOnly", "startRecording",
    )

    @Test
    fun notCohort_issuesNothing() = runTest {
        // ECPO-933: a non-cohort runner's foreground restore must not arm the KMP shield.
        restore(cohort = cohortConfig(kmpEnabled = false)).restore()
        assertTrue(shield.calls.isEmpty())
    }

    @Test
    fun notInProgress_issuesNothing_evenWithJobId() = runTest {
        // #R1: current_state.job_id survives non-in-progress stages (e.g. POST_ACCEPT) — the shield must
        // stay OFF there. The gate is the RUNNER_JOB_IN_PROGRESS widget, not the presence of a job_id.
        currentState.widget = "RUNNER_JOB_POST_ACCEPT"
        restore().restore()
        assertTrue(shield.calls.isEmpty())
    }

    @Test
    fun notInProgress_armedShield_isTornDown() = runTest {
        // #V2: restore() was raise-only, so a shield left armed outside the job window survived until
        // process death — nothing re-checked it on foreground.
        currentState.widget = "RUNNER_JOB_POST_ACCEPT"
        shield.shieldStateFlow.value = SafetyState.MONITORING
        restore().restore()
        assertEquals(listOf("onJobEnded"), shield.calls)
    }

    @Test
    fun notInProgress_duringSos_isNotTornDown() = runTest {
        // SOS is job-independent (contract §3) — a stage change must never kill a live one.
        currentState.widget = "RUNNER_JOB_POST_ACCEPT"
        shield.shieldStateFlow.value = SafetyState.SOS_PENDING
        restore().restore()
        assertTrue(shield.calls.isEmpty())
    }

    @Test
    fun notInProgress_clearsPersistedManualIntent() = runTest {
        manual.setActiveJob(650)
        currentState.widget = null
        restore().restore()
        assertNull(manual.activeJobId())    // outside an in-progress job → stale manual intent dropped
    }

    @Test
    fun snapshotFailure_abortsWithoutDowngrading() = runTest {
        currentState.snapshotFails = true // transient current_state fetch failure on foreground restore
        restore().restore()
        assertTrue(shield.calls.isEmpty())    // fail-closed: no commands issued (#R6)
    }

    @Test
    fun nativeSos_issuesNothing() = runTest {
        shield.shieldStateFlow.value = SafetyState.SOS_PENDING
        restore().restore()
        assertTrue(shield.calls.isEmpty())
    }

    @Test
    fun presentEnabledAuto_fromIdle_restoresFullLadder() = runTest {
        profile.partnerEnabled = true; profile.consentGiven = true; currentState.customerConsent = true; currentState.auto = true
        restore().restore()
        assertEquals(fullLadder, shield.calls)
    }

    // ECPO-986: in-progress but job_id still lagging — arm the safety floor + monitoring, but do NOT
    // record. A clip with no owner would be attributed to whatever the latch last held (the previous job).
    @Test
    fun inProgressWithLaggingJobId_armsFloorAndMonitoring_butDoesNotRecord() = runTest {
        profile.partnerEnabled = true; profile.consentGiven = true; currentState.customerConsent = true; currentState.auto = true
        currentState.jobId = null
        restore().restore()
        assertEquals(
            listOf("initialize", "onJobStarted", "startAccelerometerOnly", "startMonitoringOnly"),
            shield.calls,
        )
    }

    // Skipping startRecording() isn't enough: an SOS starts the recorder inside the engine off the
    // gate alone, and that clip would be stamped null → attributed to the previous job. Gate stays shut.
    @Test
    fun laggingJobId_keepsTheRecordingGateClosed_butNotMonitoringOrMl() = runTest {
        profile.partnerEnabled = true; profile.consentGiven = true; currentState.customerConsent = true; currentState.auto = true
        currentState.jobId = null
        restore().restore()
        val g = shield.lastGates
        assertEquals(false, g?.recording)
        assertEquals(true, g?.monitoring)
    }

    // Same tier, id present → the gate opens, so the SOS recorder is permitted for a job that owns it.
    @Test
    fun jobIdPresent_opensTheRecordingGate() = runTest {
        profile.partnerEnabled = true; profile.consentGiven = true; currentState.customerConsent = true; currentState.auto = true
        restore().restore()
        assertEquals(true, shield.lastGates?.recording)
    }

    @Test
    fun manualActivatedForThisJob_autoOff_restoresRecording() = runTest {
        // Auto off, but recording was MANUALLY activated for THIS job → survives resume (contract §2/§5).
        profile.partnerEnabled = true; profile.consentGiven = true; currentState.customerConsent = true; currentState.auto = false
        manual.setActiveJob(650)
        restore().restore()
        assertEquals(fullLadder, shield.calls)
    }

    @Test
    fun manualActivatedForOtherJob_autoOff_stopsAtMonitoringOnly() = runTest {
        // Manual intent belongs to a DIFFERENT job → must not leak recording into this one.
        profile.partnerEnabled = true; profile.consentGiven = true; currentState.customerConsent = true; currentState.auto = false
        manual.setActiveJob(999)
        restore().restore()
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly", "startMonitoringOnly"), shield.calls)
    }

    @Test
    fun presentNotEnabled_fromIdle_stopsAtMonitoringOnly() = runTest {
        profile.partnerEnabled = true; profile.consentGiven = true; currentState.customerConsent = true; currentState.auto = false
        restore().restore()
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly", "startMonitoringOnly"), shield.calls)
    }

    @Test
    fun notPresent_fromIdle_restoresAccelerometerFloorOnly() = runTest {
        profile.partnerEnabled = false; currentState.customerConsent = true
        restore().restore()
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly"), shield.calls)
    }

    @Test
    fun presentEnabledAuto_notConsented_restoresAccelerometerFloorOnly() = runTest {
        // Enablement present + auto, but runner consent not given → restore must not raise ML/recording.
        profile.partnerEnabled = true; currentState.customerConsent = true; currentState.auto = true
        restore().restore()
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly"), shield.calls)
    }

    @Test
    fun presentEnabledAuto_monitoringRcOff_restoresAccelerometerFloorOnly() = runTest {
        // Fully enabled + consented, but the RC cohort kill-switch is OFF → floor only.
        profile.partnerEnabled = true; profile.consentGiven = true; currentState.customerConsent = true; currentState.auto = true
        restore(rcGates()).restore()   // both cohort flags OFF
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly"), shield.calls)
    }

    @Test
    fun presentEnabledAuto_recordingRcOff_restoresMonitoringOnly() = runTest {
        // monitoring cohort ON, recording cohort OFF → monitoring-only, no recording.
        profile.partnerEnabled = true; profile.consentGiven = true; currentState.customerConsent = true; currentState.auto = true
        restore(rcGates("expert_shield_monitoring_only_enabled")).restore()
        assertEquals(listOf("initialize", "onJobStarted", "startAccelerometerOnly", "startMonitoringOnly"), shield.calls)
    }

}

package com.snabbit.runner.shared.features.kavach.shared.data
import com.snabbit.runner.shared.features.job.domain.model.JobWidgetName
import com.snabbit.runner.shared.features.kavach.shield.data.shieldConfig
import com.snabbit.runner.shared.features.kavach.shield.data.shieldMlConfig
import com.snabbit.runner.shared.features.kavach.shield.data.mlEnabled
import com.snabbit.runner.shared.features.kavach.sos.data.remote.SosApi
import com.snabbit.runner.shared.features.kavach.shield.data.remote.ShieldConsentApi
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.CurrentStateGateway
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.ShieldProfileGateway
import com.safetykavach.shield.core.model.ShieldGates
import com.snabbit.runner.shared.features.kavach.shield.data.store.JobIdCache
import com.snabbit.runner.shared.features.kavach.shield.domain.upload.ShieldSyncScheduler
import com.snabbit.runner.shared.features.kavach.shield.data.store.ModelAssetResolver
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldManualMonitoringStore
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldRcGates
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldMlLoadGuard
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTrigger
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTriggerHolder

import com.safetykavach.shield.core.ShieldController
import com.safetykavach.shield.core.event.ShieldEvent
import com.safetykavach.shield.core.model.MonitoringState
import com.safetykavach.shield.core.model.RecordingState
import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import com.snabbit.runner.shared.core.device.BatteryMonitor
import com.snabbit.runner.shared.core.device.StorageMonitor
import com.snabbit.runner.shared.storage.PreferenceStorage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.withLock
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldInitLock
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow

/**
 * Binds the Kavach feature to the safety-kavach [ShieldController] engine (Step 6, OD-1).
 * State + events mirror the plugin directly; SoS commands delegate 1:1. [activate] runs the
 * §10 enablement gate-chain (consent → enablement layer), 1:1 with the Flutter adapter.
 * [callSosTeam] dials via E4 (RC fallback phone). [conditions] surfaces battery/storage blocks.
 * Still TODO: keep-phone monitor; idempotent init + never-downgrade (§6); primary SOS `ph_no`.
 */
class SafetyDataSourceImpl(
    private val shield: ShieldController,
    private val remoteConfig: RemoteConfigGateway,
    private val modelAssets: ModelAssetResolver,
    private val sosApi: SosApi,
    private val consentApi: ShieldConsentApi,
    private val currentState: CurrentStateGateway,
    private val shieldProfile: ShieldProfileGateway,
    private val manualStore: ShieldManualMonitoringStore,
    private val prefs: PreferenceStorage,
    private val battery: BatteryMonitor,
    private val storage: StorageMonitor,
    private val analytics: AnalyticsTracker,
    private val rcGates: ShieldRcGates,
    private val mlGuard: ShieldMlLoadGuard,
    private val activeTrigger: ActiveTriggerHolder = ActiveTriggerHolder(),
    private val initLock: ShieldInitLock = ShieldInitLock(),
    private val jobIdCache: JobIdCache,
    /** Null on iOS / in tests: checkout simply doesn't kick an out-of-band drain. */
    private val syncScheduler: ShieldSyncScheduler? = null,
) : SafetyDataSource {

    override val shieldState: StateFlow<SafetyState> get() = shield.shieldState
    override val recordingState: StateFlow<RecordingState> get() = shield.recordingState
    override val monitoringState: StateFlow<MonitoringState> get() = shield.monitoringState
    override val events: SharedFlow<ShieldEvent> get() = shield.events

    override suspend fun activate(): Boolean = arm(manual = true)

    override suspend fun startForJob(): Boolean = arm(manual = false)

    // Info sheet is shown for the first N activations (RC cap), then skipped — 1:1 with Flutter's
    // maybeShowActivationSheet (prefs count vs RC max).
    override suspend fun shouldShowActivationSheet(): Boolean {
        val max = remoteConfig.getInt(RC_ACTIVATION_SHEET_MAX, DEFAULT_ACTIVATION_SHEET_MAX)
        return (prefs.getInt(KEY_ACTIVATION_SHEET_COUNT) ?: 0) < max
    }

    override suspend fun markActivationSheetShown() {
        prefs.putInt(KEY_ACTIVATION_SHEET_COUNT, (prefs.getInt(KEY_ACTIVATION_SHEET_COUNT) ?: 0) + 1)
    }

    // Serialize the plugin init check-then-act across BOTH callers — arm() (activate/startForJob) AND
    // ShieldLayerRestore.restore() — via the shared ShieldInitLock, so a concurrent manual Activate,
    // coordinator job-start, and foreground restore can't all pass the IDLE check and double-init
    // (concurrent loadModels, FGS promote/demote churn). The raise-only plugin caps STATE; this caps churn.
    private suspend fun arm(manual: Boolean): Boolean = initLock.mutex.withLock { armInner(manual) }

    private suspend fun armInner(manual: Boolean): Boolean {
        val snap = currentState.snapshot()
        // §1 job-gate + D-5 consent gate — fail-closed (contract §1/§2).
        if (snap == null) {
            analytics.track(
                "expert_shield_error",
                mapOf("error" to "activate_current_state_unavailable", "error_type" to "fetch_failure"),
            )
            error("Shield activation: current_state unavailable — cannot confirm an active job")
        }
        // §1 job-gate (#V1): only RUNNER_JOB_IN_PROGRESS is a genuinely active job. current_state.job_id
        // ALSO survives POST_ACCEPT/CHECK_IN/POST_CHECKOUT, so gating on jobId alone armed the shield —
        // FGS, notification, and recording of the runner's commute — before check-in. The auto path is
        // incidentally safe (JobKavachCoordinator only calls this on the in-progress edge); the manual
        // Activate path was not. Canonical predicate = the one ShieldLayerRestore already documents.
        if (snap.widgetName != JobWidgetName.IN_PROGRESS) return false
        if (snap.jobId == null) return false   // in-progress but current_state jobId still lags — retryable
        // ECPO-986: this job now owns every clip the plugin emits until the next arm. Latched HERE, past
        // both gates, so the upload seam can't read a lagging or already-finished job_id off the envelope.
        jobIdCache.set(snap.jobId)
        // Runner consent gates ML monitoring + recording (collected on the home consent sheet, not
        // auto-submitted here). No consent → accelerometer + SOS floor only.
        val consented = shieldProfile.runnerConsentGiven() == true

        // §2 resolved layer: present = partner ∧ customer.
        val present = shieldProfile.partnerShieldEnabled() && snap.customerConsentEnabled == true

        // Crash-guard: if a prior native ML load crashed for this build, keep ML off (accel + SOS +
        // recording still run). Surfaced so the suppressed cohort is visible.
        val mlAllowed = mlGuard.mlAllowed()
        if (!mlAllowed) {
            analytics.track("expert_shield_ml_disabled_after_crash", mapOf("reason" to "prior_ml_load_crash"))
        }

        // §16 idempotent init + never-downgrade: initialize/onJobStarted only when fresh (IDLE). The
        // plugin ShieldStateMachine guards every start* transition (raise-only), so re-issuing this
        // sequence on an already-active shield raises where needed and never downgrades.
        try {
            // Capture BEFORE the init ladder: a fresh arm starts IDLE, a re-arm doesn't. Reused for the
            // init guard and to gate the degraded emission — start* is raise-only, so a re-arm while still
            // MONITORING no-ops and must NOT report accelerometer_only.
            val wasIdle = shield.shieldState.value == SafetyState.IDLE
            if (wasIdle) {
                // Base init only — no ML load / asset extraction here. The plugin's injected crash-guard
                // now brackets the deferred native load, so no beginAttempt/markSucceeded around initialize.
                shield.initialize(shieldConfig(remoteConfig))
                // Hand the job down so the plugin stamps it on every clip this session emits (ECPO-986).
                shield.onJobStarted(snap.jobId)
            }
            // Stamp the trigger BEFORE the start* calls: ShieldEventRouter reads activeTrigger.value() off
            // the recordingState→RECORDING edge that startRecording() triggers (on a separate dispatcher),
            // so the holder must be committed first or started/resumed race to "unknown". Cold SOS overrides
            // this to "sos" from SosCoordinator (which likewise stamps before its state change).
            activeTrigger.current = if (manual) ActiveTrigger.MANUAL else ActiveTrigger.AUTO
            // Push the tier permissions BEFORE the ladder: the engine is fail-closed and enforces these
            // at every start path (incl. its own SOS auto-arm), so a closed gate can't be bypassed and
            // an RC flip actually takes ML away instead of latching it on.
            shield.setGates(
                ShieldGates(
                    monitoring = present && consented && rcGates.monitoringOnlyEnabled(),
                    recording = present && consented && rcGates.recordingEnabled(),
                    ml = mlEnabled(remoteConfig, mlAllowed),
                ),
            )
            shield.startAccelerometerOnly()                       // Layer 1a floor (no consent needed)
            // RC cohort kill-switches (Flutter ShieldRcGates parity, live Firebase RC): gate the ML
            // monitoring + recording tiers. recording ⊆ monitoring; both default OFF.
            if (present && consented && rcGates.monitoringOnlyEnabled()) {
                // ML tier: supply ML config (materializes models) so the plugin lazy-loads on monitoring start.
                if (mlEnabled(remoteConfig, mlAllowed)) shield.configureMl(shieldMlConfig(remoteConfig, modelAssets))
                shield.startMonitoringOnly()                      // mlMonitoring auto-starts → MONITORING_ONLY
                if (rcGates.recordingEnabled()) {
                    if (manual) {
                        // Manual "Activate Kavach" tap → enable recording now (regardless of auto);
                        // startRecording() from MONITORING_ONLY reaches MONITORING. Persist the manual
                        // intent keyed by jobId so restore() re-records it across resume (§2/§5).
                        shield.startRecording()
                        snap.jobId?.let { manualStore.setActiveJob(it) }
                    } else if (snap.autoEnabled == true) {
                        // Automatic job-start → record ONLY when auto_record is on (contract §2 auto path).
                        shield.startRecording()
                    }
                }
            } else if (wasIdle) {
                // Stopped at the accelerometer floor: no ML, no recording, no clip evidence. Flutter
                // emits this (expert_shield_degraded_mode_active); KMP was silent, so a runner armed
                // in degraded mode looked identical to a healthy session in analytics. Only on a fresh
                // arm — a re-arm while still MONITORING would falsely report accelerometer_only.
                analytics.track(
                    "expert_shield_degraded_mode_active",
                    mapOf(
                        "trigger" to activeTrigger.value(),
                        "mode" to "accelerometer_only",
                        "shield_state" to "accelerometer_only",
                        "reason" to degradedReason(present, consented, rcGates.monitoringOnlyEnabled()),
                    ),
                )
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            // IG-08: surface an activation failure to analytics, then let the VM map it to an error state.
            analytics.track(
                "expert_shield_error",
                mapOf(
                    "error" to "start_failed",
                    "error_type" to "exception",
                    "error_message" to (e.message ?: e.toString()),
                ),
            )
            throw e
        }
        return true
    }

    override suspend fun endForJob() = initLock.mutex.withLock {
        // Serialize teardown under the SAME lock arm()/restore() use — init and teardown are the two
        // halves of one check-then-act. Without it a manual Activate (its own scope, bypasses the
        // coordinator's lifecycleMutex) landing at job checkout can interleave the init ladder with this
        // reset-to-IDLE → shield left armed past job end / a wrong trigger on started/stopped.
        // Fire `stopped` BEFORE onJobEnded() resets the StateFlows to IDLE. Guard on armed state
        // (Flutter's isRecording || isMonitoringOnly) — an idle/accel-only-only job-end emits nothing.
        val recording = shield.recordingState.value == RecordingState.RECORDING
        val monitoring = shield.monitoringState.value == MonitoringState.ACTIVE ||
            shield.shieldState.value == SafetyState.MONITORING || shield.shieldState.value == SafetyState.MONITORING_ONLY
        val mode = if (recording) "recording" else if (monitoring) "monitoring_only" else null
        if (mode != null) {
            analytics.track("expert_shield_stopped", mapOf("reason" to "job_ended", "mode" to mode, "trigger" to activeTrigger.value()))
        }
        // Job checkout/end (Complete Job → OTP confirmed): the plugin tears down fully — dismisses SOS
        // notifications, demotes the FGS, stops the motion sensor + recording, resets the engine to IDLE
        // + syncs the StateFlows. Then drop this job's manual-record intent so it can't leak to a next job.
        shield.onJobEnded()
        // Clip sync is NOT job-scoped: hand any leftover rows to the out-of-band drain, else they wait
        // for the next job's first clip to kick the queue. Expedited — a drain already deep into its
        // backoff would otherwise swallow this and nothing would run at checkout.
        syncScheduler?.schedule(expedite = true)
        manualStore.clear()
        // Reset so the ended job's trigger can't leak into the next job's started event (Flutter parity).
        activeTrigger.current = null
    }

    override suspend fun triggerSos() = shield.triggerManualSoS()

    override suspend fun callSosTeam() {
        // E4: dial the SOS team. TODO(step6-sos-machine): prefer the active SOS `ph_no`
        // (from E2/E3) when available; RC fallback for now (matches Flutter). Blank → skip.
        val phone = remoteConfig.getString("expert_shield_sos_fallback_phone", "")
        sosApi.callSosTeam(phone)
    }

    override suspend fun endSos() = shield.deescalateSoS()

    /**
     * Battery-low / no-storage blocks (fail-open: null reading or threshold ≤ 0 never blocks —
     * parity with Flutter). Storage takes precedence. Keep-phone is not a runtime monitor. RC
     * thresholds read once per collection. NONE clears the sheet/pill.
     */
    override fun conditions(): Flow<SafetyCondition> = flow {
        val storageBlockMb = remoteConfig.getInt("expert_shield_storage_block_threshold_mb", DEFAULT_STORAGE_BLOCK_MB).toLong()
        val batteryBlockPct = remoteConfig.getInt("expert_shield_battery_block_threshold", DEFAULT_BATTERY_BLOCK_PCT)
        emitAll(
            combine(battery.batteryPercent(), storage.freeDiskMb()) { pct, freeMb ->
                when {
                    storageBlockMb > 0 && freeMb != null && freeMb < storageBlockMb -> SafetyCondition.NO_STORAGE
                    batteryBlockPct > 0 && pct != null && pct < batteryBlockPct -> SafetyCondition.BATTERY_LOW
                    else -> SafetyCondition.NONE
                }
            }.distinctUntilChanged(),
        )
    }

    /** Which gate stopped the ladder — the whole point of the event is knowing which one to chase. */
    private fun degradedReason(present: Boolean, consented: Boolean, rcOn: Boolean): String = when {
        !present -> "not_enabled"        // partner shield off, or customer consent absent
        !consented -> "no_runner_consent"
        !rcOn -> "rc_monitoring_off"
        else -> "unknown"
    }

    private companion object {
        const val DEFAULT_STORAGE_BLOCK_MB = 500
        const val DEFAULT_BATTERY_BLOCK_PCT = 15
        const val RC_ACTIVATION_SHEET_MAX = "expert_shield_activation_sheet_max_show_count"  // Flutter parity
        const val DEFAULT_ACTIVATION_SHEET_MAX = 10
        const val KEY_ACTIVATION_SHEET_COUNT = "shield_activation_sheet_shown_count"          // Flutter parity
    }
}

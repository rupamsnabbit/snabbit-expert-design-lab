package com.snabbit.runner.shared.features.kavach.shield.domain.restore

import com.safetykavach.shield.core.ShieldController
import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import com.snabbit.runner.shared.features.job.domain.model.JobWidgetName
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.CurrentStateGateway
import com.safetykavach.shield.core.model.ShieldGates
import com.snabbit.runner.shared.features.kavach.shield.data.store.JobIdCache
import com.snabbit.runner.shared.features.kavach.shield.data.store.ModelAssetResolver
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldManualMonitoringStore
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.ShieldProfileGateway
import com.snabbit.runner.shared.features.kavach.shield.data.shieldConfig
import com.snabbit.runner.shared.features.kavach.shield.data.shieldMlConfig
import com.snabbit.runner.shared.features.kavach.shield.data.mlEnabled
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldRcGates
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldInitLock
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldMlLoadGuard
import com.snabbit.runner.shared.core.realtime.RealtimeConfigStore
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTrigger
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTriggerHolder
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.withLock

/**
 * §16 expected-layer restore (1:1 with Flutter `_ensureExpectedShieldState`). Re-establishes the
 * shield's layer from enablement (present ∧ auto), so an auto MONITORING session survives a process
 * restart. Called on foreground (after reconcile) by `SafetyForegroundReconciler`.
 *
 * Raise-only + safe: the plugin `ShieldStateMachine` guards every `start*` transition
 * (`startAccelerometerOnly` only from IDLE; the rest no-op from a higher state; only the explicit
 * `downgradeToAccelerometerOnly` downgrades) — so issuing the target-layer commands raises where
 * needed and never downgrades. Guards: not in RUNNER_JOB_IN_PROGRESS, or a native SOS → no-op.
 */
class ShieldLayerRestore(
    private val shield: ShieldController,
    private val currentState: CurrentStateGateway,
    private val shieldProfile: ShieldProfileGateway,
    private val manualStore: ShieldManualMonitoringStore,
    private val remoteConfig: RemoteConfigGateway,
    private val modelAssets: ModelAssetResolver,
    private val rcGates: ShieldRcGates,
    private val analytics: AnalyticsTracker,
    // Required (no default): arm() and restore() MUST share the one Koin ShieldInitLock — a defaulted
    // fresh lock would silently re-introduce the double-init race with no compile-time signal.
    private val initLock: ShieldInitLock,
    private val mlGuard: ShieldMlLoadGuard,
    // Nullable: unbound on iOS (getOrNull) → null → not hosting → no KMP arm. ECPO-933.
    private val realtimeConfig: RealtimeConfigStore? = null,
    private val activeTrigger: ActiveTriggerHolder = ActiveTriggerHolder(),
    private val jobIdCache: JobIdCache,
) {
    suspend fun restore() {
        // Mirror armInner's guard: the only caller (SafetyForegroundReconciler) swallows throwables, so an
        // init/start failure here was a silently-unprotected session. Emit expert_shield_error for the
        // signal; best-effort (no rethrow) since restore is a recovery net.
        try {
            restoreInner()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            analytics.track(
                "expert_shield_error",
                mapOf(
                    "error" to "restore_failed",
                    "error_type" to "exception",
                    "error_message" to (e.message ?: e.toString()),
                ),
            )
        }
    }

    private suspend fun restoreInner() {
        if (realtimeConfig?.isKmpHosting() != true) return   // ECPO-933: inert for non-cohort (Flutter-flow) runners
        // One atomic read. A null snapshot is a FETCH FAILURE (network/parse) — bail (fail-closed) so a
        // foreground-restore blip can't under-arm the shield (#R6).
        val snap = currentState.snapshot() ?: return
        // Gate strictly to the check-in↔checkout window: only RUNNER_JOB_IN_PROGRESS is a genuinely
        // active job. current_state.job_id also survives non-in-progress stages (e.g. POST_ACCEPT), so
        // gating on job_id alone would re-arm the shield (FGS + SOS notification) with no live job (#R1).
        if (snap.widgetName != JobWidgetName.IN_PROGRESS) {
            manualStore.clear()   // not actively in a job → drop any stale manual-record intent
            // Reconcile DOWN as well as up (#V2). This pass is raise-only by design, so a shield left
            // armed outside the job window survived until process death — nothing else re-checked it
            // on foreground. JobKavachCoordinator tears down on the envelope edge; this is the
            // safety net for a missed/conflated edge or a coordinator that wasn't collecting yet.
            // SOS states excluded: an SOS is job-independent (contract §3) and must never be killed
            // by a stage change.
            val state = shield.shieldState.value
            val armedOutsideSos = state != SafetyState.IDLE &&
                state != SafetyState.SOS_PENDING && state != SafetyState.SOS_CONFIRMED
            if (armedOutsideSos) shield.onJobEnded()
            return
        }
        val native = shield.shieldState.value
        if (native == SafetyState.SOS_PENDING || native == SafetyState.SOS_CONFIRMED) return  // never touch during SOS

        // ECPO-986: restore arms without going through arm(), so it owns the clip-attribution latch too.
        // Past the IN_PROGRESS gate above, so this is a genuinely active job.
        snap.jobId?.let(jobIdCache::set)

        // Ensure the accelerometer floor (fresh after a restart). Serialize the init check-then-act with
        // arm() via the shared ShieldInitLock + a re-check under the lock, so a concurrent job-start
        // startForJob() and this foreground restore can't both read IDLE and double-init.
        // Crash-guard veto (same as arm): a prior native ML load-crash for this build keeps ML off — the
        // plugin's injected guard now brackets the deferred native load, so no bracket around initialize.
        val mlAllowed = mlGuard.mlAllowed()
        if (native == SafetyState.IDLE) {
            initLock.mutex.withLock {
                if (shield.shieldState.value == SafetyState.IDLE) {
                    // Base init only — ML load defers to the monitoring tier via the plugin's guarded lazy load.
                    shield.initialize(shieldConfig(remoteConfig))
                    // Same job hand-down as arm() — clips stamp their owner (ECPO-986).
                    shield.onJobStarted(snap.jobId)
                    shield.startAccelerometerOnly()
                }
            }
        }

        // Runner consent gates ML monitoring + recording (same as arm()) — restore must not bypass it.
        val consented = shieldProfile.runnerConsentGiven() == true
        val present = shieldProfile.partnerShieldEnabled() && snap.customerConsentEnabled
        // Recording re-establishes on auto OR a persisted manual activation for THIS job (contract
        // §2/§5): a manually-activated recording survives resume within the same valid job.
        val manualForThisJob = snap.jobId != null && manualStore.activeJobId() == snap.jobId

        // Same fail-closed gate push as arm() — the engine enforces these at every start path,
        // including its own SOS auto-arm.
        // `snap.jobId != null` on recording: skipping startRecording() below isn't enough on its own,
        // because an SOS starts the recorder inside the engine (triggerSoS's MONITORING_ONLY branch,
        // and the SOS auto-arm) purely off this gate. In the lagging-id window that clip would be
        // stamped null and fall back to JobIdCache — i.e. the PREVIOUS job. Keep the gate shut until
        // the id lands; detection + SOS alerting are unaffected. arm() can't hit this (it returns
        // early on a null id).
        shield.setGates(
            ShieldGates(
                monitoring = present && consented && rcGates.monitoringOnlyEnabled(),
                recording = present && consented && rcGates.recordingEnabled() && snap.jobId != null,
                ml = mlEnabled(remoteConfig, mlAllowed),
            ),
        )

        // Stamp the trigger before the start* ladder, same as armInner — the router reads it off the
        // recordingState→RECORDING edge, so it must be committed first or started/stopped report
        // "unknown". Only when unset: never clobber a live MANUAL/SOS session with a re-derived AUTO.
        if (activeTrigger.current == null) {
            activeTrigger.current = if (manualForThisJob) ActiveTrigger.MANUAL else ActiveTrigger.AUTO
        }

        // Raise only — the plugin no-ops already-satisfied / invalid transitions. startRecording()
        // from MONITORING_ONLY reaches MONITORING (both), so no separate startMonitoring() call.
        // RC cohort kill-switches (Flutter ShieldRcGates parity, live Firebase RC) — same gate as arm().
        if (present && consented && rcGates.monitoringOnlyEnabled()) {
            if (mlEnabled(remoteConfig, mlAllowed)) shield.configureMl(shieldMlConfig(remoteConfig, modelAssets))
            shield.startMonitoringOnly()
        }
        // jobId != null (ECPO-986): recording is the only clip producer, and an unowned clip lands on
        // whatever job the latch last held. Accel + monitoring still run; recording waits for the id.
        val recordingWanted = present && consented && rcGates.recordingEnabled() &&
            (snap.autoEnabled || manualForThisJob)
        if (snap.jobId != null && recordingWanted) {
            shield.startRecording()
        } else if (recordingWanted) {
            // Everything permitted recording but the job id hasn't landed — surface it, else the
            // no-recording window is invisible. JobKavachCoordinator's arm retries on the next envelope.
            analytics.track("expert_shield_restore_recording_deferred", mapOf("reason" to "job_id_lagging"))
        }
    }
}

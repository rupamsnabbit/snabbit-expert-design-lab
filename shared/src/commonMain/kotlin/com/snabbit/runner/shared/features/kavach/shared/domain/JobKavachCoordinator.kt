package com.snabbit.runner.shared.features.kavach.shared.domain

import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.lifecycle.AppLifecycle
import com.snabbit.runner.shared.core.realtime.RealtimeConfigStore
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.data.state.toJob
import com.snabbit.runner.shared.features.job.domain.model.JobState
import com.snabbit.runner.shared.features.kavach.shared.data.SafetyDataSource
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionContext
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionGate
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Owns the job ↔ Safety Kavach lifecycle. App-lived eager single (survives screen unmounts +
 * backgrounding), driven off the `RunnerStateSource` envelope so it fires on EVERY route into/out of
 * `RUNNER_JOB_IN_PROGRESS` — OTP check-in, background poll, cold-start-mid-job, checkout, cancel.
 *
 * On entering in-progress (once per job, edge-gated by [launchedJobId]):
 *  1a. MANDATORY mic gate ([KavachPermissionGate.ensure] MicOnly). Granted → launch; denied → suppress
 *      the launch + raise [micBlock] (the job screen shows a non-dismissable block → Settings).
 *  1b/1c/1d. [SafetyDataSource.startForJob] runs the gated + auto-aware enablement ladder; the plugin
 *      starts the FGS + high-priority SOS-button notification downstream.
 *
 * On LEAVING in-progress (checkout OTP confirmed → Completed, or cancel) after a launch:
 *  [SafetyDataSource.endForJob] tears the shield down gracefully. A transient null envelope (not-yet-
 *  loaded) never tears down — only a genuine non-in-progress stage does.
 *
 * A foreground return (post-Settings) silently re-checks (no re-prompt) and launches if now granted.
 * Launch + teardown are idempotent + best-effort; a transient launch failure resets the edge to retry.
 */
class JobKavachCoordinator(
    private val runnerState: RunnerStateSource,
    private val safety: SafetyDataSource,
    private val permissionGate: KavachPermissionGate,
    private val lifecycle: AppLifecycle,
    dispatchers: AppDispatchers,
    // Optional so existing test/DI constructions are unaffected; a no-op tracker keeps them silent.
    private val analytics: AnalyticsTracker? = null,
    // Nullable: unbound on iOS (getOrNull) → null → not hosting → no KMP arm. ECPO-933.
    private val realtimeConfig: RealtimeConfigStore? = null,
) {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.default)
    private val lifecycleMutex = Mutex()

    private val _micBlock = MutableStateFlow(false)
    /** True when a job is in-progress but the launch is blocked on a missing mic grant (job screen gates on this). */
    val micBlock: StateFlow<Boolean> = _micBlock.asStateFlow()

    // The in-progress job we've launched for — edge-gate so we launch once per job (re-fire on a job
    // change) and tear down once on leaving. Null = not launched / already torn down.
    private var launchedJobId: Int? = null

    init {
        scope.launch {
            runnerState.state.collect { rs ->
                val inProgressId = (rs?.toJob() as? JobState.InProgress)?.jobId
                when {
                    inProgressId != null -> if (inProgressId != launchedJobId) {
                        // Direct in-progress A→B (a conflated envelope can coalesce the idle stage between):
                        // tear down A before arming B, else B rides A's live shield session and
                        // onJobStarted(B) never fires. onLeftInProgress no-ops when nothing was launched.
                        if (launchedJobId != null) onLeftInProgress()
                        launchOnEnter(inProgressId)
                    }
                    // Envelope not loaded yet — do NOT tear down on a transient null (would kill a live session).
                    rs == null -> Unit
                    // A non-null, non-in-progress envelope = a genuine stage change (checkout/complete/cancel).
                    else -> onLeftInProgress()
                }
            }
        }
        // ON_RESUME recheck: after a mic denial, a foreground return re-checks silently and launches
        // if the runner granted in Settings. Guarded on micBlock so a healthy session never re-prompts.
        scope.launch {
            lifecycle.foreground.filter { it }.collect {
                if (!_micBlock.value) return@collect
                val jobId = (runnerState.state.value?.toJob() as? JobState.InProgress)?.jobId ?: return@collect
                if (permissionGate.isGranted(KavachPermissionContext.MicOnly)) launchOnEnter(jobId)
            }
        }
    }

    private suspend fun launchOnEnter(jobId: Int) = lifecycleMutex.withLock {
        if (jobId == launchedJobId) return  // won a race — another pass already launched this job
        if (realtimeConfig?.isKmpHosting() != true) return  // ECPO-933: non-cohort → no arm (skip retry + metric)
        try {
            when (permissionGate.ensure(KavachPermissionContext.MicOnly)) {
                KavachPermissionResult.Granted -> {
                    _micBlock.value = false
                    // startForJob no-ops (returns false) while the shield's current_state snapshot jobId
                    // still lags the in-progress envelope (cross-source lag). Bounded backoff-retry so a
                    // transient lag doesn't permanently miss the safety start; bail early if the job leaves.
                    // Consume the launch edge (launchedJobId) only on a SUCCESSFUL arm — if all retries are
                    // exhausted the edge stays open so the next envelope re-attempts, instead of leaving the
                    // job un-armed for its whole duration with the edge already burned.
                    var attempts = 0
                    var armed = false
                    var exhausted = false
                    while (true) {
                        if (safety.startForJob()) { armed = true; break }
                        if (++attempts >= ARM_RETRY_MAX) { exhausted = true; break }
                        delay(ARM_RETRY_DELAY_MS)
                        if ((runnerState.state.value?.toJob() as? JobState.InProgress)?.jobId != jobId) break
                    }
                    if (armed) launchedJobId = jobId
                    // #C1: the retry budget was spent and the shield still didn't arm (the cross-source
                    // jobId lag outran ~2.5s). The edge stays open so a later envelope re-attempts, but
                    // this is the only signal that it happened — and it'll matter more once an MQTT
                    // state source (which can lag differently) replaces the in-memory store.
                    if (exhausted) {
                        analytics?.track(
                            "expert_shield_arm_retry_exhausted",
                            mapOf("job_id" to jobId, "attempts" to attempts),
                        )
                    }
                }
                // Mic is mandatory (spec 1a) — suppress the launch + block the job screen until granted.
                KavachPermissionResult.Denied, KavachPermissionResult.NeedsSettings -> _micBlock.value = true
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            // Best-effort: a transient launch failure (e.g. fail-closed current_state) resets the edge
            // so the next envelope / foreground return retries. The plugin ladder is idempotent.
            launchedJobId = null
        }
    }

    private suspend fun onLeftInProgress() = lifecycleMutex.withLock {
        _micBlock.value = false
        // Tear down when WE launched this job, or when the shield is armed by a path that never sets
        // launchedJobId — manual "Activate Kavach" and ShieldLayerRestore both call the plugin's
        // onJobStarted() directly. Keying teardown on launchedJobId alone meant endForJob() (and the
        // plugin's isJobActive reset inside it) was skipped for those sessions, leaving the plugin
        // believing a job was live for the rest of the process.
        // SOS states are excluded: an SOS is job-independent (contract §3) and a stage change must not
        // kill a live one. A launched job still tears down mid-SOS exactly as before.
        val state = safety.shieldState.value
        val armedOutsideSos = state != SafetyState.IDLE &&
            state != SafetyState.SOS_PENDING && state != SafetyState.SOS_CONFIRMED
        if (launchedJobId == null && !armedOutsideSos) return  // nothing armed — nothing to tear down
        launchedJobId = null
        try {
            safety.endForJob()   // graceful teardown on checkout/end
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            // best-effort — a failed teardown is harmless (the plugin is idempotent; restore() re-syncs)
        }
    }

    /** Re-open OS settings — the block surface's primary action. */
    fun openAppSettings() = permissionGate.openSettings()

    private companion object {
        const val ARM_RETRY_MAX = 5           // ~2.5s total with the 500ms delay before giving up
        const val ARM_RETRY_DELAY_MS = 500L
    }
}

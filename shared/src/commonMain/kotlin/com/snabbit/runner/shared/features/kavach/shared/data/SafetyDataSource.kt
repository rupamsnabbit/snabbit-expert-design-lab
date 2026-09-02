package com.snabbit.runner.shared.features.kavach.shared.data

import com.safetykavach.shield.core.event.ShieldEvent
import com.safetykavach.shield.core.model.MonitoringState
import com.safetykavach.shield.core.model.RecordingState
import com.safetykavach.shield.core.model.SafetyState
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * App-side adapter over the safety-kavach `ShieldController` engine (Step 6, OD-1
 * "compose"). Re-exposes the plugin's reactive state + one-time events for UI
 * state-sync, and the app-intent operations the Kavach feature drives; the impl
 * composes `ShieldController` commands plus app-side concerns (SOS backend APIs,
 * upload, device-condition monitors). Actions are `suspend` + main-safe by contract.
 */
interface SafetyDataSource {
    /** Plugin shield / recording / monitoring state — mirrored so the UI stays in sync. */
    val shieldState: StateFlow<SafetyState>
    val recordingState: StateFlow<RecordingState>
    val monitoringState: StateFlow<MonitoringState>

    /** One-time plugin events (encrypted-audio, SoS-triggered, notification-action, error, …). */
    val events: SharedFlow<ShieldEvent>

    /**
     * Manual "Activate Kavach" tap — records regardless of `auto_record` + persists the intent.
     * `false` = nothing was armed because `current_state` jobId still lags the envelope; retryable
     * and thrown-free, same contract as [startForJob].
     */
    suspend fun activate(): Boolean

    /** Kavach info sheet shows for the first N activations (RC-capped, persisted) — true while under the cap. */
    suspend fun shouldShowActivationSheet(): Boolean

    /** Record that the activation info sheet was shown (bumps the persisted count). */
    suspend fun markActivationSheetShown()

    /**
     * Automatic job-start launch (fired once when a job goes in-progress). Same gate + consent +
     * enablement ladder as [activate], but records only when `auto_record` is on and never persists
     * a manual-record intent (contract §2 auto path). Mic permission is enforced upstream.
     *
     * @return true if the shield armed; false if the current_state snapshot's jobId still lags the
     * envelope (a transient no-op the caller should retry — the launch edge is otherwise consumed).
     */
    suspend fun startForJob(): Boolean

    /**
     * Job checkout/end — tear the shield down gracefully (dismiss notifications, demote the FGS, stop
     * sensors/recording, reset to IDLE) and drop this job's manual-record intent. Idempotent.
     */
    suspend fun endForJob()

    /** Raise an SOS for the active job. */
    suspend fun triggerSos()

    /** Reach the SOS team from the active-SOS screen ("Call SOS Team"). */
    suspend fun callSosTeam()

    /** End an active SOS ("I am safe"). */
    suspend fun endSos()

    /** Reactive device conditions Kavach surfaces to the runner. */
    fun conditions(): Flow<SafetyCondition>
}

/** A device condition Kavach reacts to. Maps to a sheet ([BATTERY_LOW]) or the pill ([NO_STORAGE]). */
enum class SafetyCondition { NONE, BATTERY_LOW, NO_STORAGE }

package com.snabbit.runner.shared.features.kavach.shield.domain

import com.safetykavach.shield.core.model.MlLoadGuardPort
import com.snabbit.runner.shared.storage.PreferenceStorage

/**
 * Self-healing guard for the native ML model load. `allocateTensors` inside `shield.initialize`'s
 * `loadModels` can raise SIGILL — an uncatchable native trap (e.g. an XNNPACK/CPU-instruction gap on
 * an emulator or low-end device). A plain try/catch can't stop it, so the app would crash-loop on
 * every job-start. This persists a per-app-version sentinel around the ML init so the app self-heals:
 *
 *  - [beginAttempt] writes the current app version as "pending" (awaited → durable on disk) right
 *    before the risky initialize; [markSucceeded] clears it once initialize returns.
 *  - [mlAllowed] is false when a pending marker for the CURRENT version survived — i.e. the last ML
 *    init for this build never cleared, meaning it crashed. ML then stays off (accelerometer + SOS +
 *    recording are unaffected) until a new app/model build (different version) clears the block.
 *
 * Version-keyed by [appVersion] (x-version-code) so a fixed/upgraded build re-enables ML automatically.
 * At ML-init time (job-start) the version is populated, so the marker is written + read consistently.
 */
class ShieldMlLoadGuard(
    private val prefs: PreferenceStorage,
    private val appVersion: () -> String,
) : MlLoadGuardPort {
    /** True unless a prior ML init for THIS build crashed (pending marker == current version). */
    suspend fun mlAllowed(): Boolean {
        val pending = prefs.getString(KEY_PENDING) ?: return true
        return pending != appVersion()
    }

    /** Mark an ML init as in-flight for this build. Awaited by the caller so it survives a native crash. */
    override suspend fun beginAttempt() {
        prefs.putString(KEY_PENDING, appVersion())
    }

    /** ML init returned without crashing → clear the marker. */
    override suspend fun markSucceeded() {
        prefs.remove(KEY_PENDING)
    }

    /** Port view for the plugin's lazy loader — blocked when a prior ML init for THIS build crashed. */
    override suspend fun isBlocked(): Boolean = !mlAllowed()

    private companion object {
        const val KEY_PENDING = "shield_ml_init_pending_version"
    }
}

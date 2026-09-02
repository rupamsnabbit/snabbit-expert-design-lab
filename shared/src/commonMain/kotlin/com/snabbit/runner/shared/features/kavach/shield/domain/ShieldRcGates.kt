package com.snabbit.runner.shared.features.kavach.shield.domain

import com.snabbit.runner.shared.core.config.RemoteConfigGateway

/**
 * RC cohort kill-switches for the two shield capability tiers — 1:1 with Flutter `ShieldRcGates`:
 *  - [monitoringOnlyEnabled]: Layer 1b (mic + ML monitoring, no clips).
 *  - [recordingEnabled]: recording clips + full monitoring — requires monitoring-only too.
 *
 * Reads the generic [RemoteConfigGateway] (Android: Firebase RC native via the official SDK; iOS:
 * defaults), so the tiers honor the same per-cohort flags Flutter does. Both default OFF — an unset
 * key or the iOS default gateway resolves false → fail-closed.
 */
class ShieldRcGates(private val rc: RemoteConfigGateway) {

    suspend fun monitoringOnlyEnabled(): Boolean = rc.getBoolean(KEY_MONITORING_ONLY, false)

    suspend fun recordingEnabled(): Boolean =
        monitoringOnlyEnabled() && rc.getBoolean(KEY_RECORDING, false)

    private companion object {
        const val KEY_MONITORING_ONLY = "expert_shield_monitoring_only_enabled"
        const val KEY_RECORDING = "expert_shield_recording_enabled"
    }
}

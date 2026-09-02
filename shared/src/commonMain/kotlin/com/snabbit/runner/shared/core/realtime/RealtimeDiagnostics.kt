package com.snabbit.runner.shared.core.realtime

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Process-lived realtime connection status, surfaced in the Profile footer on
 * **non-prod builds only** (debug/QA visibility — see `ProfileTabContent`).
 *
 * A Koin single so it outlives engine restarts (FGS start/stop) — [status]
 * mirrors the running engine, fed by [RealtimeHost]'s status collector; read-only
 * to consumers.
 */
class RealtimeDiagnostics {
    private val _status = MutableStateFlow<RealtimeStatus>(RealtimeStatus.Idle)

    /** Latest engine status (Connected / Degraded / PollOnly / Offline / …). */
    val status: StateFlow<RealtimeStatus> = _status.asStateFlow()

    fun updateStatus(status: RealtimeStatus) {
        _status.value = status
    }
}

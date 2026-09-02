package com.snabbit.runner.shared.features.kavach.sos.domain.deterrence
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.kavach.sos.domain.SosPhase

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Plays the SOS deterrence clip once the session enters ACTIVE (1:1 with Flutter `_startDeterrence`,
 * gated on `isSOSMode`). After an RC delay it re-checks the gate then plays + fires
 * `expert_shield_deterrence_played`; leaving ACTIVE cancels the pending play and stops audio.
 *
 * Eager Koin single, own [scope]; self-starts (mirrors [ShieldEventRouter]/[SosCoordinator]).
 * Verified pure-KMP: gated only on internal [SosCoordinator] state, never host job-context.
 */
class DeterrenceCoordinator(
    private val sos: SosCoordinator,
    private val audioPlayer: DeterrenceAudioPlayer,
    private val remoteConfig: RemoteConfigGateway,
    private val analytics: AnalyticsTracker,
    dispatchers: AppDispatchers,
) {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.default)
    private var running = false
    private var deterrenceJob: Job? = null

    init {
        start()
    }

    /** Idempotent; collects the SOS phase and drives deterrence on ACTIVE edges. */
    fun start() {
        if (running) return
        running = true
        scope.launch {
            var wasActive = false
            sos.state.collect { state ->
                val active = state.phase == SosPhase.ACTIVE
                if (active && !wasActive) schedule()
                else if (!active && wasActive) cancel()
                wasActive = active
            }
        }
    }

    private fun schedule() {
        deterrenceJob?.cancel()
        deterrenceJob = scope.launch {
            val secs = remoteConfig.getInt(RC_DELAY_KEY, DEFAULT_DELAY_SECS)
            delay(secs * 1000L)
            if (sos.state.value.phase != SosPhase.ACTIVE) return@launch   // re-check gate (isActive)
            audioPlayer.playDeterrence()
            val s = sos.state.value
            analytics.track(
                EVENT_DETERRENCE_PLAYED,
                mapOf("sos_id" to s.sosId, "source" to (s.source ?: "unknown")),
            )
        }
    }

    private fun cancel() {
        deterrenceJob?.cancel()
        deterrenceJob = null
        audioPlayer.stop()
    }

    private companion object {
        const val RC_DELAY_KEY = "expert_shield_sos_deterrence_delay_secs"
        const val DEFAULT_DELAY_SECS = 3
        const val EVENT_DETERRENCE_PLAYED = "expert_shield_deterrence_played"
    }
}

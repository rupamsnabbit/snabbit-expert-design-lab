package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.domain.audio.JobCueAssetResolver
import com.snabbit.runner.shared.features.job.domain.audio.JobCueAudioPlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Fires the two in-progress voice cues — **half-time** (50% of the job window) and **T-minus-10** —
 * off [JobViewModel.uiState], playing them natively via [JobCueAudioPlayer] (localized through
 * [LocalizationStore]). The sibling of [JobInstrumentation]: it observes the same stream, arms one-shot
 * timers keyed off the countdown seeds already on [JobUiState.InProgress], and stays single-purpose.
 *
 * **De-dup / re-arm.** Each cue fires at most once per job id. On every fresh `InProgress` envelope the
 * not-yet-fired timers are cancelled and re-armed from the newly-seeded `remainingSeconds`, so a mid-job
 * duration extension re-times them and successive envelopes keep the fire accurate. A timer arms only
 * when its moment is still in the FUTURE (`delay > 0`) — a moment already passed when the screen mounts
 * is never retro-fired. A transient non-`InProgress` state (e.g. `Loading` on a cold refresh) cancels
 * pending timers but keeps `fired`/`jobId`, so a flicker back into the job doesn't replay a fired cue.
 *
 * **Per-cue RC control.** Playback is suppressed when the job's duration (minutes) is in that cue's
 * Remote Config exclusion list ([RC_HALF_TIME_EXCLUDED] / [RC_TEN_MIN_EXCLUDED]). An empty/malformed
 * list plays for all durations (fail-open, matching the host-owned auto-checkout cue).
 *
 * **Auto-checkout is deliberately NOT here** — it is push-driven and fires in the background/killed FCM
 * isolate where KMP is not alive, so it stays host-owned (Dart `loopSound` → `LocalizedAudioService`).
 */
class JobAudioCueScheduler(
    private val player: JobCueAudioPlayer,
    private val localization: LocalizationStore,
    private val remoteConfig: RemoteConfigGateway,
    private val scope: CoroutineScope,
    private val analytics: JobAnalytics,
) {
    // The job whose cues are currently armed/fired (null when not in a job).
    private var jobId: Int? = null
    // Cues already fired for [jobId] — one fire per cue per job id.
    private val fired = mutableSetOf<String>()
    // Armed-but-not-yet-fired timers, so a fresh envelope can cancel + re-arm without double-firing.
    private val timers = mutableMapOf<String, Job>()

    /** Start observing the lifecycle stream. Call once (from [JobViewModel.init]). */
    fun observe(state: StateFlow<JobUiState>) {
        scope.launch { state.collect { onState(it) } }
    }

    private fun onState(state: JobUiState) {
        if (state !is JobUiState.InProgress) {
            // Transient (Loading) or terminal (Completed / NotInJobFlow): cancel pending cues so none
            // fires after we've left the in-progress screen. Keep `fired`/`jobId` so a Loading flicker
            // back into InProgress doesn't replay an already-fired cue; a genuinely new job resets below.
            cancelPendingTimers()
            return
        }
        if (state.jobId != jobId) {
            val hadPreviousJob = jobId != null
            cancelPendingTimers()
            fired.clear()
            jobId = state.jobId
            if (hadPreviousJob) player.stop() // new job → cut any clip still playing from the previous one
        }
        arm(JobCueAssetResolver.CUE_HALF_TIME, state.durationMinutes, halfTimeDelaySeconds(state))
        arm(JobCueAssetResolver.CUE_TEN_MINUTES, state.durationMinutes, tenMinuteDelaySeconds(state))
    }

    /** Seconds until remaining time first reaches half the full window; null if unknowable (no duration)
     *  or already past half-time. */
    private fun halfTimeDelaySeconds(state: JobUiState.InProgress): Int? {
        if (state.durationMinutes == null || state.totalSeconds <= 0) return null
        return (state.remainingSeconds - state.totalSeconds / 2).takeIf { it > 0 }
    }

    /** Seconds until remaining time first reaches 10 minutes; null if already inside the final 10 min,
     *  or when the full window is ≤ 20 min (short-job guard). */
    private fun tenMinuteDelaySeconds(state: JobUiState.InProgress): Int? {
        // Short-job guard: when the known window is ≤ 20 min, the T-10 moment (remaining == 600s) collides
        // with — or for < 20 min precedes — half-time (remaining == totalSeconds/2 ≤ 600s); both would land
        // on ~the same tick and the second play would cut the first off mid-word. Skip T-10 there and let
        // half-time alone carry the cue. `totalSeconds == 0` means the duration is UNKNOWN (not a short
        // job) → T-10 still fires off `remainingSeconds`.
        if (state.totalSeconds in 1..(TEN_MINUTES_SECONDS * 2)) return null
        return (state.remainingSeconds - TEN_MINUTES_SECONDS).takeIf { it > 0 }
    }

    private fun arm(cue: String, durationMinutes: Int?, delaySeconds: Int?) {
        if (cue in fired) return
        timers.remove(cue)?.cancel()
        if (delaySeconds == null) return
        if (isExcluded(cue, durationMinutes)) return
        timers[cue] = scope.launch {
            delay(delaySeconds * MILLIS_PER_SECOND)
            fired.add(cue) // mark fired even if the clip is missing — don't retry every envelope
            timers.remove(cue)
            val language = localization.snapshot().language
            // Only report the cue as played when the clip actually played (a missing-asset language
            // no-ops in the player). Report the language actually VOICED (unmapped/blank → the Hindi
            // fallback) so `audio_language` matches what the runner heard, not the raw preference —
            // parity with the Dart auto-checkout event.
            if (player.play(JobCueAssetResolver.path(cue, language))) {
                analytics.jobInProgressAudioPlayed(
                    cue = cue,
                    language = JobCueAssetResolver.resolvedLanguage(language),
                    durationMinutes = durationMinutes,
                )
            }
        }
    }

    /** True when [durationMinutes] is listed in [cue]'s RC exclusion list (so the cue is suppressed). */
    private fun isExcluded(cue: String, durationMinutes: Int?): Boolean {
        if (durationMinutes == null) return false
        val key = if (cue == JobCueAssetResolver.CUE_HALF_TIME) RC_HALF_TIME_EXCLUDED else RC_TEN_MIN_EXCLUDED
        return durationMinutes in parseDurations(remoteConfig.getString(key, DEFAULT_LIST))
    }

    /** A "[30, 45]"-style JSON array (or bare CSV) of excluded durations → the minute values.
     *  Tolerant: strips brackets/spaces, drops non-numeric entries → malformed yields empty (play). */
    private fun parseDurations(raw: String): Set<Int> =
        raw.trim().trim('[', ']')
            .split(',')
            .mapNotNull { it.trim().toIntOrNull() }
            .toSet()

    private fun cancelPendingTimers() {
        timers.values.forEach { it.cancel() }
        timers.clear()
    }

    companion object {
        const val RC_HALF_TIME_EXCLUDED = "expert_job_audio_half_time_excluded_durations"
        const val RC_TEN_MIN_EXCLUDED = "expert_job_audio_ten_min_excluded_durations"
        private const val DEFAULT_LIST = "[]"
        private const val TEN_MINUTES_SECONDS = 600
        private const val MILLIS_PER_SECOND = 1000L
    }
}

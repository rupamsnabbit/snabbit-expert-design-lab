package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.features.job.FakeJobCueAudioPlayer
import com.snabbit.runner.shared.features.job.JobAnalytics
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Virtual-time tests for the half-time / T-10 cue scheduler. Mirrors `DeterrenceCoordinatorTest`:
 * arm on a state emission, then `advanceTimeBy(...); runCurrent()` to fire a timer at its exact moment.
 *
 * Timing model for a fresh 60-min job (`total = 3600s`, `remaining = 3600s`): half-time fires after
 * `3600 - 1800 = 1800s`, T-10 after `3600 - 600 = 3000s`.
 */
class JobAudioCueSchedulerTest {

    private val HALF_TIME_HINDI = "assets/notification_sounds/hi/half_time_hindi.mp3"
    private val TEN_MIN_HINDI = "assets/notification_sounds/hi/ten_minutes_hindi.mp3"

    private fun localization(language: String): LocalizationStore =
        LocalizationStore(FakeLogger(), CrashReporter { _, _ -> }).also { it.pushMessages(language, "{}") }

    /** Fake for the SYNC `core.remoteconfig.RemoteConfigGateway` (distinct from the suspend
     *  `core.config` one the shared FakeRemoteConfigGateway implements). */
    private fun rc(vararg pairs: Pair<String, String>): RemoteConfigGateway {
        val map = pairs.toMap()
        return object : RemoteConfigGateway {
            override fun getBool(key: String, default: Boolean) = default
            override fun getString(key: String, default: String) = map[key] ?: default
        }
    }

    private fun inProgress(
        jobId: Int?,
        durationMinutes: Int?,
        totalSeconds: Int,
        remainingSeconds: Int,
    ) = JobUiState.InProgress(
        jobId = jobId,
        durationMinutes = durationMinutes,
        totalSeconds = totalSeconds,
        remainingSeconds = remainingSeconds,
    )

    @Test
    fun bothCuesFireAtTheirMomentsInTheRunnerLanguage() = runTest {
        val player = FakeJobCueAudioPlayer()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("HINDI"), rc(), backgroundScope, JobAnalytics(FakeAnalyticsTracker())).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()

        advanceTimeBy(1_800_000); runCurrent()
        assertEquals(listOf(HALF_TIME_HINDI), player.played)

        advanceTimeBy(1_200_000); runCurrent()
        assertEquals(listOf(HALF_TIME_HINDI, TEN_MIN_HINDI), player.played)
    }

    @Test
    fun firesCtMpAnalyticsWithCueLanguageAndDurationWhenACuePlays() = runTest {
        val player = FakeJobCueAudioPlayer()
        val tracker = FakeAnalyticsTracker()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("HINDI"), rc(), backgroundScope, JobAnalytics(tracker))
            .observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(1_800_000); runCurrent()

        val event = tracker.events.single { it.name == "job_in_progress_audio_played" }
        assertEquals("half_time", event.props["cue"])
        assertEquals("HINDI", event.props["audio_language"])
        assertEquals(60, event.props["job_duration_minutes"])
    }

    @Test
    fun shortJobUnderTwentyMinutesSkipsTenMinuteCue() = runTest {
        // 20-min job: half-time (remaining == totalSeconds/2 == 600s) and T-10 (remaining == 600s) would
        // land on the same tick and the second play would cut the first off — the short-job guard drops
        // T-10 so half-time alone plays.
        val player = FakeJobCueAudioPlayer()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("HINDI"), rc(), backgroundScope, JobAnalytics(FakeAnalyticsTracker())).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 20, totalSeconds = 1200, remainingSeconds = 1200)
        runCurrent()
        advanceTimeBy(1_200_000); runCurrent()

        assertEquals(listOf(HALF_TIME_HINDI), player.played)
    }

    @Test
    fun analyticsReportsResolvedLanguageForAnUnmappedPreference() = runTest {
        // An unmapped language plays the Hindi fallback clip; analytics must report the language actually
        // heard ("HINDI"), not the raw "BENGALI" preference.
        val player = FakeJobCueAudioPlayer()
        val tracker = FakeAnalyticsTracker()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("BENGALI"), rc(), backgroundScope, JobAnalytics(tracker)).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(1_800_000); runCurrent()

        assertEquals(listOf(HALF_TIME_HINDI), player.played)
        val event = tracker.events.single { it.name == "job_in_progress_audio_played" }
        assertEquals("HINDI", event.props["audio_language"])
    }

    @Test
    fun excludedDurationSuppressesOnlyThatCue() = runTest {
        val player = FakeJobCueAudioPlayer()
        val tracker = FakeAnalyticsTracker()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        // Half-time excluded for 60-min jobs; T-10 list left at the default (plays).
        val gateway = rc(JobAudioCueScheduler.RC_HALF_TIME_EXCLUDED to "[60]")
        JobAudioCueScheduler(player, localization("HINDI"), gateway, backgroundScope, JobAnalytics(tracker)).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(3_600_000); runCurrent()

        assertEquals(listOf(TEN_MIN_HINDI), player.played)
        // No analytics for the suppressed half-time cue — only the ten-minute cue is reported.
        val cues = tracker.events.filter { it.name == "job_in_progress_audio_played" }.map { it.props["cue"] }
        assertEquals(listOf("ten_minutes"), cues)
    }

    @Test
    fun noAnalyticsWhenPlaybackNoOps() = runTest {
        // A language whose clip isn't bundled → the player no-ops (returns false); the event must NOT fire.
        val player = FakeJobCueAudioPlayer().apply { playSucceeds = false }
        val tracker = FakeAnalyticsTracker()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("HINDI"), rc(), backgroundScope, JobAnalytics(tracker)).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(3_600_000); runCurrent()

        assertTrue(player.played.isEmpty())
        assertTrue(tracker.events.none { it.name == "job_in_progress_audio_played" })
    }

    @Test
    fun malformedExclusionListFailsOpenAndPlays() = runTest {
        val player = FakeJobCueAudioPlayer()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        val gateway = rc(JobAudioCueScheduler.RC_HALF_TIME_EXCLUDED to "not-a-list")
        JobAudioCueScheduler(player, localization("HINDI"), gateway, backgroundScope, JobAnalytics(FakeAnalyticsTracker())).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(1_800_000); runCurrent()

        assertEquals(listOf(HALF_TIME_HINDI), player.played)
    }

    @Test
    fun aMomentAlreadyPastWhenMountedNeverFires() = runTest {
        val player = FakeJobCueAudioPlayer()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("HINDI"), rc(), backgroundScope, JobAnalytics(FakeAnalyticsTracker())).observe(state)
        runCurrent()

        // Only 1000s remain of a 60-min job → half-time (needs 1800s remaining) is already past; T-10
        // (needs 600s remaining) is still 400s away.
        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 1000)
        runCurrent()
        advanceTimeBy(3_600_000); runCurrent()

        assertEquals(listOf(TEN_MIN_HINDI), player.played)
    }

    @Test
    fun nullDurationSkipsHalfTimeButTenMinStillFires() = runTest {
        val player = FakeJobCueAudioPlayer()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("HINDI"), rc(), backgroundScope, JobAnalytics(FakeAnalyticsTracker())).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = null, totalSeconds = 0, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(3_600_000); runCurrent()

        assertEquals(listOf(TEN_MIN_HINDI), player.played)
    }

    @Test
    fun eachCueFiresAtMostOnceAcrossEnvelopeChurn() = runTest {
        val player = FakeJobCueAudioPlayer()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("HINDI"), rc(), backgroundScope, JobAnalytics(FakeAnalyticsTracker())).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(1_800_000); runCurrent()
        assertEquals(listOf(HALF_TIME_HINDI), player.played)

        // A fresh envelope for the SAME job (e.g. a poll refresh) must not re-arm the already-fired cue.
        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 1700)
        runCurrent()
        advanceTimeBy(3_600_000); runCurrent()

        assertEquals(1, player.played.count { it == HALF_TIME_HINDI })
    }

    @Test
    fun loadingFlickerDoesNotReplayAFiredCue() = runTest {
        val player = FakeJobCueAudioPlayer()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("HINDI"), rc(), backgroundScope, JobAnalytics(FakeAnalyticsTracker())).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(1_800_000); runCurrent()
        assertEquals(listOf(HALF_TIME_HINDI), player.played)

        // Transient Loading (cold refresh) then back into the same job → no half-time replay.
        state.value = JobUiState.Loading
        runCurrent()
        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 1500)
        runCurrent()
        advanceTimeBy(3_600_000); runCurrent()

        assertEquals(1, player.played.count { it == HALF_TIME_HINDI })
    }

    @Test
    fun newJobResetsFiredAndStopsThePreviousClip() = runTest {
        val player = FakeJobCueAudioPlayer()
        val state = MutableStateFlow<JobUiState>(JobUiState.Loading)
        JobAudioCueScheduler(player, localization("HINDI"), rc(), backgroundScope, JobAnalytics(FakeAnalyticsTracker())).observe(state)
        runCurrent()

        state.value = inProgress(jobId = 1, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(1_800_000); runCurrent()
        assertEquals(1, player.played.count { it == HALF_TIME_HINDI })

        // A different job → reset (fired cleared) + stop the previous job's clip; its half-time can fire.
        state.value = inProgress(jobId = 2, durationMinutes = 60, totalSeconds = 3600, remainingSeconds = 3600)
        runCurrent()
        advanceTimeBy(1_800_000); runCurrent()

        assertEquals(2, player.played.count { it == HALF_TIME_HINDI })
        assertTrue(player.stopCount >= 1)
    }
}

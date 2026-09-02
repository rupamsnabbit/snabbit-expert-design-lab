package com.snabbit.runner.shared.features.job.domain.audio

import kotlin.test.Test
import kotlin.test.assertEquals

class JobCueAssetResolverTest {

    @Test
    fun resolvesEachSupportedLanguage() {
        assertEquals(
            "assets/notification_sounds/hi/half_time_hindi.mp3",
            JobCueAssetResolver.path(JobCueAssetResolver.CUE_HALF_TIME, "HINDI"),
        )
        assertEquals(
            "assets/notification_sounds/mr/ten_minutes_marathi.mp3",
            JobCueAssetResolver.path(JobCueAssetResolver.CUE_TEN_MINUTES, "MARATHI"),
        )
        assertEquals(
            "assets/notification_sounds/ka/ten_minutes_kannada.mp3",
            JobCueAssetResolver.path(JobCueAssetResolver.CUE_TEN_MINUTES, "KANNADA"),
        )
        assertEquals(
            "assets/notification_sounds/te/half_time_telugu.mp3",
            JobCueAssetResolver.path(JobCueAssetResolver.CUE_HALF_TIME, "TELUGU"),
        )
    }

    @Test
    fun englishFallsBackToHindiUntilEnClipsAreBundled() {
        // The en/ half-time & ten-minutes clips aren't shipped yet, so ENGLISH must resolve to the Hindi
        // fallback (audible) rather than a missing en/ asset (silent cue), and report the language heard.
        assertEquals(
            "assets/notification_sounds/hi/half_time_hindi.mp3",
            JobCueAssetResolver.path(JobCueAssetResolver.CUE_HALF_TIME, "ENGLISH"),
        )
        assertEquals("HINDI", JobCueAssetResolver.resolvedLanguage("ENGLISH"))
    }

    @Test
    fun isCaseInsensitive() {
        assertEquals(
            "assets/notification_sounds/hi/half_time_hindi.mp3",
            JobCueAssetResolver.path(JobCueAssetResolver.CUE_HALF_TIME, "hindi"),
        )
        assertEquals("MARATHI", JobCueAssetResolver.resolvedLanguage("marathi"))
    }

    @Test
    fun blankOrUnknownLanguageFallsBackToHindi() {
        assertEquals(
            "assets/notification_sounds/hi/half_time_hindi.mp3",
            JobCueAssetResolver.path(JobCueAssetResolver.CUE_HALF_TIME, ""),
        )
        assertEquals(
            "assets/notification_sounds/hi/ten_minutes_hindi.mp3",
            JobCueAssetResolver.path(JobCueAssetResolver.CUE_TEN_MINUTES, "FRENCH"),
        )
        // resolvedLanguage reports the language actually voiced (Hindi), not the raw preference.
        assertEquals("HINDI", JobCueAssetResolver.resolvedLanguage(""))
        assertEquals("HINDI", JobCueAssetResolver.resolvedLanguage("FRENCH"))
    }
}

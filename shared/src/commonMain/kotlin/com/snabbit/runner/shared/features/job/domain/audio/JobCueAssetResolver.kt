package com.snabbit.runner.shared.features.job.domain.audio

/**
 * Resolves a job-cue key + the runner's language to the bundled localized asset path.
 *
 * Tracks the Dart `LocalizedAudioService._langToAsset` map
 * (`lib/services/localized_audio_service.dart`) — the server-driven UPPERCASE language name →
 * (folder, filename-suffix), with **Hindi** as the final fallback. Kept in sync by hand: there is no
 * shared config across the Dart/Kotlin boundary today (the localization language string is mirrored to
 * KMP as-is via `LocalizationStore`, e.g. `"HINDI"`).
 *
 * **`ENGLISH` diverges from the Dart map on purpose.** This resolver serves only the two KMP cues
 * (half-time / T-10), whose `en/` clips are not bundled yet — so `ENGLISH` is omitted here and English
 * runners get the Hindi fallback (audible) instead of a missing `en/` asset (a silent cue). The Dart map
 * keeps `ENGLISH` because it also serves job-acceptance / not-moving / auto-OT, which DO ship `en/`
 * clips. Re-add `ENGLISH` here (and drop the auto-checkout English guard in the Dart service) once the
 * `en/` half-time & ten-minutes clips land.
 *
 * Asset layout (`pubspec.yaml` bundles these): `assets/notification_sounds/<folder>/<cue>_<suffix>.mp3`.
 */
object JobCueAssetResolver {
    /** Cue keys — the filename stem under each language folder. */
    const val CUE_HALF_TIME = "half_time"
    const val CUE_TEN_MINUTES = "ten_minutes"

    /** Language the blank/unknown/unmapped fallback resolves to (Hindi) — reported to analytics as the
     *  language actually heard. */
    const val FALLBACK_LANGUAGE = "HINDI"

    private data class LangAsset(val folder: String, val suffix: String)

    // No "ENGLISH" row — see the class KDoc: the en/ half-time & ten-minutes clips aren't bundled, so
    // English resolves to the Hindi fallback below rather than a missing en/ asset.
    private val langToAsset = mapOf(
        "HINDI" to LangAsset("hi", "hindi"),
        "MARATHI" to LangAsset("mr", "marathi"),
        "KANNADA" to LangAsset("ka", "kannada"),
        "TELUGU" to LangAsset("te", "telugu"),
    )

    // Final fallback when the language is blank/unknown — Hindi (parity with the Dart service).
    private val fallback = LangAsset("hi", "hindi")

    /**
     * Full Flutter asset path for [cueKey] in [language] — e.g. `HINDI` + `half_time` →
     * `assets/notification_sounds/hi/half_time_hindi.mp3`. Blank/unknown language → Hindi.
     */
    fun path(cueKey: String, language: String): String {
        val asset = langToAsset[language.uppercase()] ?: fallback
        return "assets/notification_sounds/${asset.folder}/${cueKey}_${asset.suffix}.mp3"
    }

    /**
     * The language actually voiced for [language] — the language itself when we ship its clips, else
     * [FALLBACK_LANGUAGE] (Hindi) when it falls back. Reported to analytics so `audio_language` reflects
     * what the runner heard, not an unmapped/blank preference.
     */
    fun resolvedLanguage(language: String): String =
        if (langToAsset.containsKey(language.uppercase())) language.uppercase() else FALLBACK_LANGUAGE
}

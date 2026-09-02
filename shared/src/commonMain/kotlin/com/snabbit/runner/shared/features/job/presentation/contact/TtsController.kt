package com.snabbit.runner.shared.features.job.presentation.contact

/**
 * Read-aloud (text-to-speech) seam for the navigation card's "Listen" pill — a host bridge like
 * [CustomerContactHandler] / the location provider (mirrors the Flutter `flutter_tts` usage). The
 * host constructs a real platform controller (Android `TextToSpeech`, iOS `AVSpeechSynthesizer`) and
 * passes it down; previews / tests / un-hosted screens use [NoOpTtsController]. The host owns the
 * engine lifecycle (init / shutdown), so nothing platform-specific leaks into commonMain.
 */
interface TtsController {
    /** Speak [text] aloud, replacing anything currently being spoken. Blank text is a no-op. */
    fun speak(text: String)

    /** Stop any in-progress speech (e.g. when the runner leaves the screen). */
    fun stop()
}

/** No-op controller — the default when no host TTS is wired (previews, tests, un-hosted screens). */
object NoOpTtsController : TtsController {
    override fun speak(text: String) = Unit
    override fun stop() = Unit
}

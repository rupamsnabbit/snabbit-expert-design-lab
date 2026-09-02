package com.snabbit.runner.shared.features.job.presentation.contact

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

/**
 * Android [TtsController] for the check-in navigation card's "Listen" pill — reads the address aloud
 * via the platform [TextToSpeech] engine. Constructed and owned by the job host
 * ([com.snabbit.runner.shared.features.bottomnav.ActiveJobOverlay]), which releases it via [shutdown]
 * from a `DisposableEffect` when state leaves the job flow, so the native engine is freed with the
 * screen. (iOS supplies its own `AVSpeechSynthesizer`-backed controller when that host is built.)
 *
 * The engine initialises asynchronously; a [speak] issued before it is ready is held in [pending] and
 * flushed once init succeeds. `QUEUE_FLUSH` so each tap replaces any in-progress utterance. [engine]
 * is a nullable field (not a `val` initialised with a self-referencing listener) so the init callback
 * — which may fire before construction returns on some devices — reads it null-safely.
 */
class AndroidTtsController(context: Context) : TtsController {

    @Volatile private var ready = false
    @Volatile private var failed = false
    @Volatile private var pending: String? = null
    private var engine: TextToSpeech? = null

    init {
        engine = TextToSpeech(context.applicationContext) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) {
                // Hindi (hi-IN) for parity with the Flutter `_speakAddress` (flutterTts.setLanguage("hi-IN")).
                // Fall back to the device default when hi-IN voice data isn't installed (setLanguage
                // returns LANG_MISSING_DATA / LANG_NOT_SUPPORTED) so the address is still read aloud.
                val result = engine?.setLanguage(Locale("hi", "IN"))
                if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                    engine?.setLanguage(Locale.getDefault())
                }
                pending?.let { text ->
                    pending = null
                    speakNow(text)
                }
            } else {
                // Init never succeeded — drop any queued text so it isn't held forever, and surface
                // the failure once (the "Listen" pill no-ops from here).
                failed = true
                pending = null
                android.util.Log.w(TAG, "TTS init failed (status=$status); Listen unavailable")
            }
        }
    }

    override fun speak(text: String) {
        if (failed) return
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        if (ready) speakNow(trimmed) else pending = trimmed
    }

    override fun stop() {
        pending = null
        engine?.stop()
    }

    private fun speakNow(text: String) {
        engine?.speak(text, TextToSpeech.QUEUE_FLUSH, null, UTTERANCE_ID)
    }

    /** Release the engine — call from the host when state leaves the job flow. */
    fun shutdown() {
        pending = null
        engine?.stop()
        engine?.shutdown()
    }

    private companion object {
        const val TAG = "AndroidTtsController"
        const val UTTERANCE_ID = "snabbit_listen"
    }
}

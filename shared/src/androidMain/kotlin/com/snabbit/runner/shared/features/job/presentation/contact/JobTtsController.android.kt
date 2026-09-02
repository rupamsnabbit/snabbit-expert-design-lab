package com.snabbit.runner.shared.features.job.presentation.contact

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext

/**
 * Android [rememberJobTtsController]: builds an [AndroidTtsController] on the host `Context`
 * (it downgrades to `applicationContext` internally, so no Activity leak) and shuts the native
 * `TextToSpeech` engine down via `onDispose` when this leaves composition — the same
 * built-on-appear / released-on-leave lifecycle the old `JobActivity` host owned.
 */
@Composable
actual fun rememberJobTtsController(): TtsController {
    val context = LocalContext.current
    val tts = remember { AndroidTtsController(context) }
    DisposableEffect(Unit) { onDispose { tts.shutdown() } }
    return tts
}

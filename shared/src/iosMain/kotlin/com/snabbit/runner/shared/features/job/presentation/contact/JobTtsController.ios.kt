package com.snabbit.runner.shared.features.job.presentation.contact

import androidx.compose.runtime.Composable

/**
 * iOS [rememberJobTtsController]: [NoOpTtsController] for now — keeps the shared shell compiling
 * for iOS. Consequence: the check-in card's "Listen" pill is **silently inert** on iOS (the
 * address is not read aloud).
 *
 * TODO: wire an `AVSpeechSynthesizer`-backed [TtsController] (`speak`/`stop`/`shutdown`, hi-IN with
 * device-default fallback — mirror `AndroidTtsController`) when the iOS host ships, and give the
 * pill a disabled/hidden state there instead of a silent no-op.
 */
@Composable
actual fun rememberJobTtsController(): TtsController = NoOpTtsController

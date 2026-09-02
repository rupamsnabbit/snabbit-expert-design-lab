package com.snabbit.runner.shared.features.job.presentation.contact

import androidx.compose.runtime.Composable

/**
 * Remembers a platform [TtsController] scoped to the calling composition — the "Listen" pill's
 * read-aloud engine for the check-in card ([com.snabbit.runner.shared.features.bottomnav.ActiveJobOverlay]).
 *
 * A `@Composable expect`/`actual` seam (like `OnAppResumed`) so the platform engine **and its
 * lifecycle** stay out of `commonMain`: the Android actual builds an [AndroidTtsController] on the
 * host `Context` and releases the native engine via a `DisposableEffect` when this leaves
 * composition (i.e. when state exits the job flow); the iOS actual returns [NoOpTtsController] until
 * an `AVSpeechSynthesizer`-backed controller is wired for that host.
 */
@Composable
expect fun rememberJobTtsController(): TtsController

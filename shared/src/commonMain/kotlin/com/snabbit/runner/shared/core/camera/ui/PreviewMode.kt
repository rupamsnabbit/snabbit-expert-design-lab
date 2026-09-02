package com.snabbit.runner.shared.core.camera.ui

import com.snabbit.runner.shared.core.camera.CapturedMedia

/**
 * How (or whether) to preview a captured artifact before the result
 * leaves the camera module.
 *
 * Sealed so the three behaviours are mutually exclusive at compile time
 * (vs. a `Boolean + nullable callback` which permits invalid combos).
 *
 * - [Disabled] — no preview; the capture result is emitted immediately
 *   (backward-compatible default for the existing selfie flow).
 * - [Default] — the built-in [MediaPreviewScreen] with Retake/Submit.
 * - [Custom] — the caller fully controls presentation (navigate to a new
 *   screen, show a bottom sheet, …). The module hands over the captured
 *   media plus the two resolution levers and waits for one to fire.
 */
sealed interface PreviewMode {

    /** No preview — result returned immediately. */
    data object Disabled : PreviewMode

    /**
     * Built-in preview screen. [strings] `null` (the default) resolves the
     * `composeResources` fallbacks at render time via [rememberPreviewStrings];
     * pass a value to override with server-driven labels. Kept nullable (rather
     * than eagerly building [PreviewStrings]) because this is a plain sealed type,
     * not a composable — the resource lookup must happen inside composition.
     */
    data class Default(
        val strings: PreviewStrings? = null,
    ) : PreviewMode

    /**
     * Caller-driven preview. [present] is invoked from the composition
     * layer with a [PreviewRequest]; the caller decides how to show it.
     * Any exception thrown by [present] falls back to [Default].
     */
    data class Custom(
        val present: (PreviewRequest) -> Unit,
    ) : PreviewMode
}

/**
 * Handed to a [PreviewMode.Custom] presenter. Carries the captured media
 * and the two levers the caller invokes to resolve the preview:
 *
 * - [onRetake] — discard this capture, return to the capture screen.
 * - [onSubmit] — accept this capture; the module emits the result via
 *   its `result` flow and the host closes the camera.
 */
data class PreviewRequest(
    val media: CapturedMedia,
    val onRetake: () -> Unit,
    val onSubmit: () -> Unit,
)

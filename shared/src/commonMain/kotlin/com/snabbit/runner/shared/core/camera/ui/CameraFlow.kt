package com.snabbit.runner.shared.core.camera.ui

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraLens
import com.snabbit.runner.shared.core.camera.CameraOverlay
import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.camera.CaptureMode
import com.snabbit.runner.shared.core.camera.CapturedMedia

import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.compose.viewmodel.koinViewModel
import org.koin.core.parameter.parametersOf

/**
 * Top-level entry point for the camera module. Owns the capture↔preview
 * navigation ([CameraUiState.preview]) and renders the right child:
 *
 * - `preview == null` → [CameraScreen] (live preview + capture)
 * - `preview != null` → either the built-in [MediaPreviewScreen]
 *   ([PreviewMode.Default]) or the caller's presenter ([PreviewMode.Custom]).
 *
 * The [CameraViewModel] is resolved via `koinViewModel`, parameterised with the
 * analytics [source] and [previewMode]. One-shot results are surfaced through
 * [onResult] / [onDismiss] (collected from `viewModel.effects` here, at the flow
 * level, so a Submit fired from the preview screen is never missed).
 *
 * Hosts (shift login, training, go-live, …) configure behaviour entirely
 * through parameters — a new use case is configuration, not a fork:
 *
 * @param source analytics launch context ("go_live", "shift_login", …).
 * @param onResult invoked once when a capture is accepted — the host uploads it
 *   and closes the flow.
 * @param onDismiss invoked once when the flow should close without a result (cancel).
 * @param captureStrings capture-screen labels; defaults to the `composeResources`
 *   fallbacks via [rememberCameraStrings]. Pass server-driven i18n to override.
 * @param config camera lens / mode / quality.
 * @param previewMode whether/how to preview a capture before delivering it.
 * @param allowBack `false` locks the user on the flow (mandatory capture).
 * @param overlay drawn over the live preview; defaults to the selfie face
 *   guide for front+photo via [defaultOverlay]. Future flows (document, QR)
 *   pass their own guide — the module stays closed for modification.
 * @param captureContent optional caller-supplied capture UI. When non-null the
 *   module renders the live preview full-bleed and hands this content a
 *   [CameraCaptureScope] (state + shutter / mic / settings actions) to draw its own
 *   chrome; when null the built-in capture screen is used.
 * @param onNavigateUp invoked when the user backs out of the capture screen.
 */
@Composable
fun CameraFlow(
    source: String,
    onResult: (CameraResult) -> Unit,
    onDismiss: () -> Unit,
    captureStrings: CameraStrings = rememberCameraStrings(),
    modifier: Modifier = Modifier,
    config: CameraConfig = CameraConfig(),
    previewMode: PreviewMode = PreviewMode.Disabled,
    allowBack: Boolean = true,
    overlay: (@Composable BoxScope.() -> Unit)? = defaultOverlay(config),
    captureContent: (@Composable BoxScope.(CameraCaptureScope) -> Unit)? = null,
    onNavigateUp: (() -> Unit)? = null,
) {
    val viewModel = koinViewModel<CameraViewModel> { parametersOf(source, previewMode) }
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Flow-level effect collector — always composed, so a Submit/Dismiss fired
    // from the preview screen is never missed.
    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is CameraEffect.DeliverResult -> onResult(effect.result)
                CameraEffect.Dismiss -> onDismiss()
            }
        }
    }

    val preview = state.preview
    if (preview == null) {
        CameraScreen(
            viewModel = viewModel,
            strings = captureStrings,
            modifier = modifier,
            config = config,
            allowBack = allowBack,
            overlay = overlay,
            // No-preview path only: lets CameraK return the capture as a file
            // (returnFilePath) when the caller opted in (config.saveToGallery).
            // CameraK's files are app-private (directory = DOCUMENTS); the public
            // gallery publish, if any, is the MediaPersister's job on accept.
            saveToGalleryOnCapture = !viewModel.isPreviewEnabled && config.saveToGallery,
            captureContent = captureContent,
            onNavigateUp = onNavigateUp,
        )
    } else {
        // Front-camera photos arrive mirrored from the sensor (no EXIF flag).
        // Un-mirror them in the preview decode so the still matches a natural
        // photo. Back camera and video are never mirrored.
        val mirror = config.lens == CameraLens.FRONT && config.mode == CaptureMode.PHOTO

        // S1: reclaim the private temp if the preview is abandoned (disposed
        // without Retake/Submit, e.g. process teardown). No-op after a
        // resolution — the VM's atomic guard prevents racing the host save.
        DisposableEffect(preview) {
            onDispose { viewModel.dispatch(CameraIntent.PreviewDisposed) }
        }
        when (val mode = viewModel.previewMode) {
            is PreviewMode.Custom -> CustomPreviewHost(
                media = preview,
                present = mode.present,
                onRetake = { viewModel.dispatch(CameraIntent.Retake) },
                onSubmit = { viewModel.dispatch(CameraIntent.Submit) },
                modifier = modifier,
                mirror = mirror,
            )
            is PreviewMode.Default -> MediaPreviewScreen(
                media = preview,
                // null strings → the composeResources fallbacks (resolved here, in composition).
                strings = mode.strings ?: rememberPreviewStrings(),
                onRetake = { viewModel.dispatch(CameraIntent.Retake) },
                onSubmit = { viewModel.dispatch(CameraIntent.Submit) },
                modifier = modifier,
                mirror = mirror,
            )
            // Unreachable: Disabled never holds a preview. Render the default
            // screen defensively rather than crash.
            PreviewMode.Disabled -> MediaPreviewScreen(
                media = preview,
                strings = rememberPreviewStrings(),
                onRetake = { viewModel.dispatch(CameraIntent.Retake) },
                onSubmit = { viewModel.dispatch(CameraIntent.Submit) },
                modifier = modifier,
                mirror = mirror,
            )
        }
    }
}

/**
 * Invokes a [PreviewMode.Custom] presenter once for [media]. If the
 * presenter throws, falls back to the built-in [MediaPreviewScreen] so the
 * user is never stranded with a captured-but-invisible photo.
 */
@Composable
private fun CustomPreviewHost(
    media: CapturedMedia,
    present: (PreviewRequest) -> Unit,
    onRetake: () -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
    mirror: Boolean = false,
) {
    var fellBack by remember(media) { mutableStateOf(false) }

    LaunchedEffect(media) {
        try {
            present(PreviewRequest(media, onRetake, onSubmit))
        } catch (_: Throwable) {
            fellBack = true
        }
    }

    if (fellBack) {
        MediaPreviewScreen(
            media = media,
            strings = rememberPreviewStrings(),
            onRetake = onRetake,
            onSubmit = onSubmit,
            modifier = modifier,
            mirror = mirror,
        )
    }
    // Otherwise the caller's own UI (new screen / bottom sheet) is on top;
    // the module renders nothing here.
}

/**
 * The default overlay for a given config — the composition guide selected by
 * [CameraConfig.overlay], drawn only for photo capture:
 * - [CameraOverlay.FACE] → the selfie [FaceGuideOverlay] (front camera only).
 * - [CameraOverlay.OVAL] → the dashed [OvalGuideOverlay] (any lens).
 * - [CameraOverlay.NONE] → no overlay.
 *
 * Video capture never shows a guide. Callers can still override [CameraFlow]'s
 * `overlay` parameter directly for a bespoke guide (document, QR, …).
 */
fun defaultOverlay(config: CameraConfig): (@Composable BoxScope.() -> Unit)? {
    if (config.mode != CaptureMode.PHOTO) return null
    return when (config.overlay) {
        CameraOverlay.NONE -> null
        // The head+shoulders silhouette only makes sense on the front (selfie) camera.
        CameraOverlay.FACE ->
            if (config.lens == CameraLens.FRONT) {
                { FaceGuideOverlay(modifier = Modifier.fillMaxSize()) }
            } else {
                null
            }
        CameraOverlay.OVAL -> {
            { OvalGuideOverlay(modifier = Modifier.fillMaxSize()) }
        }
    }
}

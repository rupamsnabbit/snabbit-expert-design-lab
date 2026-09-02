package com.snabbit.runner.shared.core.camera.ui

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraResult

/**
 * Every input to [CameraViewModel], as data. The UI plus the lifecycle/watchdog
 * hooks send these to [CameraViewModel.dispatch] — a single input funnel, so all
 * state transitions live in one exhaustive `when` (child composables receive a
 * `dispatch` lambda, never the ViewModel).
 */
sealed interface CameraIntent {
    /** Screen entered — run the permission gate once (idempotent). */
    data object Start : CameraIntent

    /** User tapped "Allow" on the denied state — re-request. */
    data object RequestPermission : CameraIntent

    /** User tapped "Open settings" on the permanently-denied state. */
    data object OpenAppSettings : CameraIntent

    /** Host returned to the foreground (ON_RESUME) — re-check permission. */
    data object Resumed : CameraIntent

    /** CameraK preview reached Ready. */
    data object CameraReady : CameraIntent

    /** CameraK failed to initialize. */
    data class CameraError(val message: String) : CameraIntent

    /** Init watchdog fired — surfaces an error only if still Initializing. */
    data object CameraInitTimeout : CameraIntent

    /** Capture watchdog fired — surfaces an error only if still Capturing. */
    data object CaptureTimeout : CameraIntent

    /** Recording watchdog fired — surfaces an error only if still Recording. */
    data object RecordingTimeout : CameraIntent

    /**
     * Shutter tapped. The VM decides the action from [CameraUiState.config] +
     * [CameraPhase]: a photo capture, or a video start/stop toggle.
     */
    data object ShutterPressed : CameraIntent

    /** User tapped the "audio off" banner's enable action — re-request the mic. */
    data object RequestMicrophone : CameraIntent

    /** CameraK delivered a capture outcome (mapped from its event). */
    data class CaptureCompleted(val result: CameraResult) : CameraIntent

    /** Preview "Retake" — discard the artifact and return to capture. */
    data object Retake : CameraIntent

    /** Preview "Submit" — accept the artifact and deliver it. */
    data object Submit : CameraIntent

    /** Preview left composition without a resolution — reclaim the temp. */
    data object PreviewDisposed : CameraIntent

    /** Back on the capture screen — cancel the whole flow. */
    data object CancelRequested : CameraIntent

    /** Update the camera config (e.g. switch lens / mode). */
    data class ConfigChanged(val config: CameraConfig) : CameraIntent
}

package com.snabbit.runner.shared.core.camera.ui

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraPermissionStatus
import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.camera.CapturedMedia

/**
 * Immutable UI state for the camera flow.
 *
 * Following the build-screen standard: derived booleans live here,
 * not in the composable.
 *
 * [preview] carries the capture↔preview navigation that used to be a separate
 * `CameraFlowState`: `null` renders the live capture screen; a non-null value
 * renders the preview screen for that captured artifact.
 */
data class CameraUiState(
    val phase: CameraPhase = CameraPhase.CheckingPermission,
    val config: CameraConfig = CameraConfig(),
    val lastResult: CameraResult? = null,
    val errorMessage: String? = null,
    /** Microphone status for audio video — GRANTED until a request says otherwise. */
    val micPermission: CameraPermissionStatus = CameraPermissionStatus.GRANTED,
    /**
     * The captured artifact currently held for review, or `null` while on the
     * live capture screen. Set on a successful capture when preview is enabled;
     * cleared on Retake. [CameraFlow] switches capture vs. preview on this.
     */
    val preview: CapturedMedia? = null,
    /**
     * Debounces the async video record start/stop so a double-tap can't fire it
     * twice. Owned here (was composable-local) so the shutter button can reflect
     * it: set while a record action is in flight and, for a stop-tap, held true
     * until the recording actually ends (the video stop-tap fix). No effect on
     * photo capture.
     */
    val recordActionInFlight: Boolean = false,
) {
    /** Audio was requested but the mic isn't granted (recording is silent). */
    val microphoneDenied: Boolean
        get() = micPermission != CameraPermissionStatus.GRANTED

    /** Mic is permanently denied — only app settings can grant it. */
    val microphonePermanentlyDenied: Boolean
        get() = micPermission == CameraPermissionStatus.PERMANENTLY_DENIED

    /** The CameraK preview may be composed (permission granted, initializing or live). */
    val canShowCamera: Boolean
        get() = phase is CameraPhase.Initializing ||
            phase is CameraPhase.Ready ||
            phase is CameraPhase.Capturing ||
            phase is CameraPhase.Recording

    /** Camera is ready and the user can capture. */
    val canCapture: Boolean
        get() = phase is CameraPhase.Ready

    /** A capture is currently in progress. */
    val isCapturing: Boolean
        get() = phase is CameraPhase.Capturing

    /** A video recording is currently in progress. */
    val isRecording: Boolean
        get() = phase is CameraPhase.Recording

    /** The screen is in an unrecoverable-by-retry-here error state. */
    val hasError: Boolean
        get() = phase is CameraPhase.Error

    /** A permission gate is blocking the camera (denied or permanently denied). */
    val needsPermission: Boolean
        get() = phase is CameraPhase.PermissionDenied ||
            phase is CameraPhase.PermissionPermanentlyDenied
}

/**
 * Lifecycle phases of the camera capture screen.
 *
 * Permission gate → camera init → ready → capturing, with terminal error.
 */
sealed interface CameraPhase {
    /** Checking/awaiting the camera permission decision (initial). */
    data object CheckingPermission : CameraPhase

    /** Permission denied but re-requestable (show rationale + "Allow"). */
    data object PermissionDenied : CameraPhase

    /** Permission permanently denied — only app settings can grant it. */
    data object PermissionPermanentlyDenied : CameraPhase

    /** Permission granted; camera hardware is initializing. */
    data object Initializing : CameraPhase

    /** Camera is live and ready to capture. */
    data object Ready : CameraPhase

    /** A capture is in flight. */
    data object Capturing : CameraPhase

    /** A video recording is in flight (start → stop / max-duration). */
    data object Recording : CameraPhase

    /** Camera initialization or capture failed. */
    data class Error(val message: String) : CameraPhase
}

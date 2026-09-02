package com.snabbit.runner.shared.core.camera.ui

/**
 * The seam for a caller-supplied capture UI — the capture-side counterpart to
 * [PreviewMode.Custom]. Passed to a `captureContent` lambda by [CameraFlow] /
 * [CameraScreen].
 *
 * The camera module keeps ownership of the CameraK **engine**: the live preview
 * surface, the permission gate, the init/capture/recording watchdogs, the portrait
 * lock, and the actual capture triggering. A custom capture UI is pure **chrome** —
 * it reads [uiState] and calls the actions below; it never touches CameraK, and the
 * module renders the live preview full-bleed behind the custom content.
 *
 * Anything the built-in chrome shows (shutter, REC/audio HUD, composition guides)
 * the custom UI is free to draw itself from [uiState]; the public
 * `FaceGuideOverlay` / `OvalGuideOverlay` composables can be reused for guides.
 */
interface CameraCaptureScope {
    /**
     * Live capture state — the [CameraPhase], the derived `canCapture` /
     * `isRecording` / `microphoneDenied` flags, and the active `config`. This is
     * what the custom UI renders against.
     */
    val uiState: CameraUiState

    /**
     * Shutter action. In `PHOTO` mode it takes a photo; in `VIDEO` mode it toggles
     * recording start/stop based on [uiState]. Idempotent and debounced — safe to
     * wire straight to a button; a no-op when the camera isn't Ready or an action
     * is already in flight.
     */
    fun onShutter()

    /**
     * Re-request the microphone — the recovery affordance for the "audio off" state
     * on an audio `VIDEO` capture. Harmless for photo.
     */
    fun onRequestMicrophone()

    /** Open the OS app-settings screen (permission recovery). */
    fun onOpenAppSettings()
}

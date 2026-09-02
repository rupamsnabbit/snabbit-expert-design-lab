package com.snabbit.runner.shared.core.camera

/**
 * Public API for the camera module.
 *
 * Callers (bifrost handlers, native Compose screens) depend on this
 * interface — never on [CameraProvider] or any camera library type.
 *
 * Obtain an instance via [cameraModule], which wires the platform-specific
 * [CameraProvider] behind the scenes.
 *
 * ## Two invocation paths
 *
 * **Path 1 — WebView (bifrost):** `CaptureMediaHandler` parses the RPC
 * payload into a [CameraConfig], calls [capture], then registers the
 * result in [CaptureRegistry] and returns the asset-loader URL.
 *
 * **Path 2 — Native Compose:** Any screen calls [capture] directly.
 * No bifrost ceremony.
 */
interface CameraModule {

    /**
     * Opens the camera and waits for the user to capture or cancel.
     *
     * Dispatches to [CameraProvider.capturePhoto] or
     * [CameraProvider.captureVideo] based on [config]'s [CaptureMode].
     *
     * Includes a reentrancy guard: if a capture is already in flight,
     * returns [CameraResult.Error] with [CameraErrorCode.CAPTURE_IN_PROGRESS]
     * immediately.
     */
    suspend fun capture(config: CameraConfig = CameraConfig()): CameraResult

    /**
     * Programmatically cancels an in-flight capture. The suspended
     * [capture] call returns [CameraResult.Cancelled].
     * No-op when nothing is in flight.
     */
    fun cancel()

    /** Whether a capture is currently in progress. */
    val isCapturing: Boolean
}

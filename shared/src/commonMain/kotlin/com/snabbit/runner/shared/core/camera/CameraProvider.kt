package com.snabbit.runner.shared.core.camera

/**
 * The library abstraction boundary.
 *
 * This is the **only** interface that camera libraries (CameraK, Camposer,
 * or any future library) implement. Everything above this —
 * [CameraModule], handlers, [CaptureRegistry] — is library-agnostic and
 * never changes when swapping libraries.
 *
 * **Swap surface:** To switch from CameraK to Camposer (or vice versa),
 * replace the [CameraProvider] implementation in `androidMain`/`iosMain`
 * and update the one-line factory in `CameraModule.android.kt` /
 * `CameraModule.ios.kt`. Zero changes to business logic, handlers, or UI.
 */
interface CameraProvider {

    /**
     * Captures a still photo according to [config].
     * Suspends until the user captures or cancels.
     */
    suspend fun capturePhoto(config: CameraConfig): CameraResult

    /**
     * Records a video according to [config].
     * Suspends until the user stops recording, cancels, or
     * [CameraConfig.maxVideoDurationMs] is reached.
     */
    suspend fun captureVideo(config: CameraConfig): CameraResult

    /**
     * Programmatically cancels an in-flight capture session.
     * The suspended [capturePhoto] or [captureVideo] call should return
     * [CameraResult.Cancelled]. No-op if nothing is in flight.
     */
    fun cancel()

    /** Whether a capture session is currently in progress. */
    val isCapturing: Boolean
}

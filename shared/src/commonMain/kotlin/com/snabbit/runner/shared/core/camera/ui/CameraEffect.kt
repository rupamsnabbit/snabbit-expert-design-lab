package com.snabbit.runner.shared.core.camera.ui

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraResult

/**
 * One-shot events from [CameraViewModel] to the host. Collected once at the
 * [CameraFlow] level, which is always composed (so a Submit fired from the
 * preview screen is never missed). Distinct from [CameraCommand], which drives
 * the CameraK hardware and has a different collector.
 */
sealed interface CameraEffect {
    /** A capture was accepted — the host uploads it and closes the flow. */
    data class DeliverResult(val result: CameraResult) : CameraEffect

    /** The flow should close without a result (user cancelled). */
    data object Dismiss : CameraEffect
}

/**
 * Hardware commands from [CameraViewModel] to the live capture surface
 * (the capture area of [CameraScreen], which owns the CameraK state holder and
 * is composed only while capturing/recording). Kept separate from
 * [CameraEffect] because the two streams have non-overlapping single collectors:
 * commands only ever fire while the capture surface is on screen.
 */
sealed interface CameraCommand {
    /** Fire a still capture on the CameraK holder. */
    data object CapturePhoto : CameraCommand

    /** Start recording with [config]'s audio + max-duration settings. */
    data class StartRecording(val config: CameraConfig) : CameraCommand

    /** Stop the in-flight recording. */
    data object StopRecording : CameraCommand
}

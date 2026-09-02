package com.snabbit.runner.shared.core.camera

/**
 * A camera-layer failure carrying a machine-readable [code].
 *
 * Reported to the core [com.snabbit.runner.shared.core.CrashReporter] when the
 * underlying failure has no throwable of its own — permission / init / capture
 * errors that the camera flow surfaces as domain results ([CameraResult.Error])
 * rather than exceptions. When a real cause exists (a thrown gallery-save /
 * permission-controller error) that throwable is reported directly instead, and
 * the [code] travels in the crash report's `meta` map.
 *
 * @param code machine-readable code, typically a [CameraErrorCode] constant.
 */
class CameraException(
    val code: String,
    message: String,
) : Exception(message)

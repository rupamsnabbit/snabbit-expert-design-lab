package com.snabbit.runner.shared.core.camera.ui

/**
 * Non-composable seam for reading device memory pressure.
 *
 * Injected via Koin (resolved with `koinInject` in [CameraScreen]) rather than
 * read through a `@Composable` platform function, so the capture screen's
 * quality-downgrade decision is unit-testable and the platform coupling lives
 * behind an interface. [isLow] is a cheap synchronous read, taken once just
 * before the live camera preview is composed.
 */
interface DeviceMemory {
    /**
     * `true` when the device is under memory pressure at read time.
     *
     * A budget-device safeguard layered on top of CameraK's runtime memory
     * manager: when `true` the capture screen drops to the lowest
     * [com.snabbit.runner.shared.core.camera.CaptureQuality] to cut the peak
     * memory used while encoding the photo. It **never blocks** the camera — a
     * partner on a tight device must still be able to capture.
     */
    fun isLow(): Boolean
}

/**
 * Reports memory as never low. The safe default for iOS (camera path stubbed)
 * and for tests / hosts that don't wire a platform reader — the capture screen
 * simply keeps the requested quality.
 */
object AmpleDeviceMemory : DeviceMemory {
    override fun isLow(): Boolean = false
}

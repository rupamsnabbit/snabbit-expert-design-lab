package com.snabbit.runner.shared.core.camera.di

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.camera.CameraModule
import com.snabbit.runner.shared.core.camera.internal.PlatformFileOps

/**
 * Platform factory for [CameraModule] — the camera module's construction entry
 * point, grouped under `di/` like the sibling modules' Koin modules.
 *
 * The headless [CameraModule]'s provider maps CameraK events via the shared
 * [PlatformFileOps] seam (the same one the Compose path uses), so it is threaded
 * in here from `cameraKoinModule`. Each platform provides an `actual` that wires
 * the appropriate `CameraProvider` (e.g. `CameraKProvider`).
 */
expect fun cameraModule(
    logger: Logger,
    dispatchers: AppDispatchers,
    fileOps: PlatformFileOps,
): CameraModule

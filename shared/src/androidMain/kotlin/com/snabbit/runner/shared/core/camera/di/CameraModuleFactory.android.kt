package com.snabbit.runner.shared.core.camera.di

import com.snabbit.runner.shared.core.camera.CameraModule
import com.snabbit.runner.shared.core.camera.internal.CameraKProvider
import com.snabbit.runner.shared.core.camera.internal.CameraModuleImpl

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.camera.internal.PlatformFileOps

/**
 * Android factory for [CameraModule].
 *
 * Wires [CameraKProvider] as the [CameraProvider] implementation, handing it the
 * shared [PlatformFileOps] for its CameraK→domain event mapping.
 *
 * **SWAP POINT:** To switch to Camposer, replace `CameraKProvider(...)`
 * with `CamposerProvider(...)` — this is the only line that changes.
 */
actual fun cameraModule(
    logger: Logger,
    dispatchers: AppDispatchers,
    fileOps: PlatformFileOps,
): CameraModule {
    val provider = CameraKProvider(logger, fileOps)
    return CameraModuleImpl(provider, logger, dispatchers)
}

package com.snabbit.runner.shared.core.camera.di

import com.snabbit.runner.shared.core.camera.CameraModule
import com.snabbit.runner.shared.core.camera.internal.CameraKProvider
import com.snabbit.runner.shared.core.camera.internal.CameraModuleImpl

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.camera.internal.PlatformFileOps

/**
 * iOS factory for [CameraModule].
 *
 * Wires [CameraKProvider] as the [CameraProvider] implementation.
 * iOS CameraK uses AVFoundation under the hood.
 *
 * [fileOps] is accepted for signature parity with the Android factory but unused:
 * the iOS provider is a stub that never maps CameraK events yet. Wire it into the
 * provider when the iOS CameraKProvider / mapper is implemented (iOS launch).
 */
actual fun cameraModule(
    logger: Logger,
    dispatchers: AppDispatchers,
    fileOps: PlatformFileOps,
): CameraModule {
    val provider = CameraKProvider(logger)
    return CameraModuleImpl(provider, logger, dispatchers)
}

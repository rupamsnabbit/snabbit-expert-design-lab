package com.snabbit.runner.shared.hello

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger
import platform.UIKit.UIDevice

actual fun helloModule(
    logger: Logger,
    dispatchers: AppDispatchers,
): HelloModule {
    val device = UIDevice.currentDevice
    return HelloModuleImpl(
        platformLabel = "${device.systemName} ${device.systemVersion}",
        logger = logger,
        dispatchers = dispatchers,
    )
}

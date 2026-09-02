package com.snabbit.runner.shared.hello

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger

actual fun helloModule(
    logger: Logger,
    dispatchers: AppDispatchers,
): HelloModule {
    val osVersion = android.os.Build.VERSION.RELEASE ?: "unknown"
    return HelloModuleImpl(
        platformLabel = "Android $osVersion",
        logger = logger,
        dispatchers = dispatchers,
    )
}

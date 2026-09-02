package com.snabbit.runner.shared.hello

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.withContext

/**
 * [HelloModule] implementation. Constructed via [helloModule] in production;
 * instantiated directly with fakes in tests.
 *
 * `internal` visibility — callers depend on the [HelloModule] interface.
 */
internal class HelloModuleImpl(
    private val platformLabel: String,
    private val logger: Logger,
    private val dispatchers: AppDispatchers,
) : HelloModule {

    override suspend fun getHelloMessage(): String = withContext(dispatchers.default) {
        logger.d(TAG, "Generating hello message for $platformLabel")
        "Hello from KMP shared module, running on $platformLabel!"
    }

    private companion object {
        const val TAG = "HelloModule"
    }
}

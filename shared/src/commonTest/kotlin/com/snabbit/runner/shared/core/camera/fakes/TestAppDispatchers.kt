package com.snabbit.runner.shared.core.camera.fakes

import com.snabbit.runner.shared.core.AppDispatchers
import kotlinx.coroutines.CoroutineDispatcher

/**
 * Test [AppDispatchers] that routes all dispatchers to a single
 * [TestDispatcher], so coroutines run inline during tests.
 */
internal class TestAppDispatchers(
    private val dispatcher: CoroutineDispatcher,
) : AppDispatchers {
    override val io: CoroutineDispatcher get() = dispatcher
    override val default: CoroutineDispatcher get() = dispatcher
    override val main: CoroutineDispatcher get() = dispatcher
}

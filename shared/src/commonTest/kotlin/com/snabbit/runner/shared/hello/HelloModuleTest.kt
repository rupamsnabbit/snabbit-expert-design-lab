package com.snabbit.runner.shared.hello

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.FakeLogger
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HelloModuleTest {

    private val logger = FakeLogger()
    private val module: HelloModule = HelloModuleImpl(
        platformLabel = "TestOS 1.0",
        logger = logger,
        dispatchers = TestAppDispatchers,
    )

    @Test
    fun getHelloMessage_includesPlatformLabel() = runTest {
        val message = module.getHelloMessage()
        assertTrue("TestOS 1.0" in message, "Expected platform label in message, got: $message")
    }

    @Test
    fun getHelloMessage_emitsDebugLog() = runTest {
        module.getHelloMessage()
        val debugEntry = logger.entries.singleOrNull { it.level == FakeLogger.Level.DEBUG }
        assertEquals("HelloModule", debugEntry?.tag)
    }
}

/** Minimal [AppDispatchers] for tests — runs every coroutine inline. */
private object TestAppDispatchers : AppDispatchers {
    override val io: CoroutineDispatcher = Dispatchers.Unconfined
    override val default: CoroutineDispatcher = Dispatchers.Unconfined
    override val main: CoroutineDispatcher = Dispatchers.Unconfined
}

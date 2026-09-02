package com.snabbit.runner.shared.core

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers

actual fun defaultAppDispatchers(): AppDispatchers = IosAppDispatchers

private object IosAppDispatchers : AppDispatchers {
    // Kotlin/Native does not provide Dispatchers.IO; Default is the
    // recommended substitute for I/O-bound work on iOS targets.
    override val io: CoroutineDispatcher = Dispatchers.Default
    override val default: CoroutineDispatcher = Dispatchers.Default
    override val main: CoroutineDispatcher = Dispatchers.Main
}

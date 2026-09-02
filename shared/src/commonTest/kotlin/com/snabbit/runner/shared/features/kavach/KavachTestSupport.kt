package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.core.AppDispatchers
import kotlinx.coroutines.CoroutineDispatcher

/** [AppDispatchers] backed by a single test dispatcher (for coordinator scope/timer tests). */
fun testAppDispatchers(dispatcher: CoroutineDispatcher): AppDispatchers = object : AppDispatchers {
    override val io: CoroutineDispatcher = dispatcher
    override val default: CoroutineDispatcher = dispatcher
    override val main: CoroutineDispatcher = dispatcher
}

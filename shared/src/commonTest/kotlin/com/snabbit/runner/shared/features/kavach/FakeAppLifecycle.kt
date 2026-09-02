package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.core.lifecycle.AppLifecycle
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Drive [foregroundFlow] to simulate app foreground/background in tests. */
class FakeAppLifecycle(initial: Boolean = false) : AppLifecycle {
    val foregroundFlow = MutableStateFlow(initial)
    override val foreground: StateFlow<Boolean> = foregroundFlow
}

package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.core.connectivity.Connectivity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Drive [flow] to simulate offline/online edges. */
class FakeConnectivity(initial: Boolean = false) : Connectivity {
    val flow = MutableStateFlow(initial)
    override val online: StateFlow<Boolean> = flow
}

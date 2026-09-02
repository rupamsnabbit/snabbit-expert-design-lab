package com.snabbit.runner.shared.features.job

import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Test [RunnerStateSource]. [emit] pushes a new envelope; [refreshCount] records
 * refreshes; [postActions] records the feature-#4 post-action labels in order.
 */
class FakeRunnerStateSource(initial: RunnerState? = null) : RunnerStateSource {
    private val _state = MutableStateFlow(initial)
    override val state: StateFlow<RunnerState?> = _state.asStateFlow()

    var refreshCount = 0
        private set

    val postActions = mutableListOf<String>()

    override fun requestRefresh() {
        refreshCount++
    }

    override fun onPostAction(action: String) {
        postActions += action
    }

    fun emit(state: RunnerState?) {
        _state.value = state
    }
}

package com.snabbit.runner.shared.core.lifecycle

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Whole-process foreground via [ProcessLifecycleOwner]. Adding the observer replays the current
 * state, so [foreground] self-corrects to `true` immediately when the app is already resumed.
 * Must be constructed on the main thread (LifecycleRegistry enforces it).
 */
private class AndroidAppLifecycle : AppLifecycle, DefaultLifecycleObserver {
    private val _foreground = MutableStateFlow(false)
    override val foreground: StateFlow<Boolean> = _foreground.asStateFlow()

    init {
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
    }

    override fun onStart(owner: LifecycleOwner) { _foreground.value = true }
    override fun onStop(owner: LifecycleOwner) { _foreground.value = false }
}

actual fun platformAppLifecycle(): AppLifecycle = AndroidAppLifecycle()

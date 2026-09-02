package com.snabbit.runner.shared.core.lifecycle

import kotlinx.coroutines.flow.StateFlow

/**
 * App-wide foreground/background signal, platform-sourced. Read-only; emits the current value
 * on collect. Android = `ProcessLifecycleOwner` (whole-process start/stop); iOS = `UIApplication`
 * active/background notifications.
 */
interface AppLifecycle {
    /** `true` while the app is in the foreground. */
    val foreground: StateFlow<Boolean>
}

/** Platform app-lifecycle source. Construct on the main thread (registers an OS observer). */
expect fun platformAppLifecycle(): AppLifecycle

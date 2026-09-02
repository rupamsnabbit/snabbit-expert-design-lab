package com.snabbit.runner.shared.core.lifecycle

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import platform.Foundation.NSNotificationCenter
import platform.Foundation.NSOperationQueue
import platform.UIKit.UIApplication
import platform.UIKit.UIApplicationDidBecomeActiveNotification
import platform.UIKit.UIApplicationDidEnterBackgroundNotification
import platform.UIKit.UIApplicationState

/**
 * App-active state via `UIApplication` notifications. Observers are app-lifetime (this is a
 * Koin single) so the returned tokens are intentionally not retained/removed.
 */
private class IosAppLifecycle : AppLifecycle {
    private val _foreground = MutableStateFlow(false)
    override val foreground: StateFlow<Boolean> = _foreground.asStateFlow()

    init {
        // Seed the current state: NSNotificationCenter won't replay an already-fired
        // DidBecomeActive, so a single built while the app is active would otherwise stay false and
        // e.g. the SoS auto-deny gate (which reads foreground) would never fire (#lc). Construction
        // is on the main thread (per platformAppLifecycle's contract), so reading applicationState is safe.
        _foreground.value = UIApplication.sharedApplication.applicationState == UIApplicationState.UIApplicationStateActive
        val center = NSNotificationCenter.defaultCenter
        center.addObserverForName(UIApplicationDidBecomeActiveNotification, null, NSOperationQueue.mainQueue) {
            _foreground.value = true
        }
        center.addObserverForName(UIApplicationDidEnterBackgroundNotification, null, NSOperationQueue.mainQueue) {
            _foreground.value = false
        }
    }
}

actual fun platformAppLifecycle(): AppLifecycle = IosAppLifecycle()

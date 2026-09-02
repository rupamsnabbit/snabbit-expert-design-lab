package com.snabbit.runner.overlayhost

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.LifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner

/**
 * Custom [LifecycleOwner] and [SavedStateRegistryOwner] for hosting Jetpack
 * Compose inside a [android.app.Service] context (which doesn't have a
 * lifecycle by default).
 *
 * [ComposeOverlayHost] creates an instance and drives it through the standard
 * lifecycle events (CREATE → START → RESUME → PAUSE → STOP → DESTROY) so that
 * ComposeView, image loading, and LaunchedEffect coroutines work correctly
 * outside of an Activity.
 *
 * The generic host ships its own copy in its own package — the identical class
 * in the legacy AWOL overlay package is a pure deletion target; nothing new
 * may import from there (TRD §8).
 */
class OverlayLifecycleOwner : LifecycleOwner, SavedStateRegistryOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateRegistryController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateRegistryController.savedStateRegistry

    fun onCreate() {
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
    }

    fun onStart() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
    }

    fun onResume() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    fun onPause() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    }

    fun onStop() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
    }

    fun onDestroy() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    }
}

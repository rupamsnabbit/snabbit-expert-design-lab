package com.snabbit.runner.compose_overlay.service

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner

/**
 * Custom [LifecycleOwner] and [SavedStateRegistryOwner] for hosting Jetpack
 * Compose inside a [Service] context (which doesn't have a lifecycle by default).
 *
 * [OverlayService] creates an instance and drives it through the standard
 * lifecycle events (CREATE → START → RESUME → PAUSE → STOP → DESTROY)
 * so that ComposeView, coil image loading, and LaunchedEffect coroutines
 * work correctly outside of an Activity.
 */
class OverlayLifecycleOwner : LifecycleOwner, SavedStateRegistryOwner, ViewModelStoreOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateRegistryController = SavedStateRegistryController.create(this)

    // Lets a Service-hosted overlay own androidx.lifecycle.ViewModels: `viewModelScope` is created against
    // this store and cancelled when [onDestroy] clears it — so ViewModels torn down with the window.
    override val viewModelStore = ViewModelStore()

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
        // Clear hosted ViewModels (cancels their viewModelScope) when the overlay window goes away.
        viewModelStore.clear()
    }
}

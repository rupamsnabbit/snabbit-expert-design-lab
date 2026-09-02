package com.snabbit.runner.shared.core.network

import kotlinx.atomicfu.atomic

/**
 * Koin-resolvable single-instance dispatcher for 401 notifications (§3.6).
 *
 * Replaces the old closure-based [UnauthorizedHandler]. The KMP module's
 * [com.snabbit.runner.shared.core.network.interceptors.UnauthorizedResponseObserver]
 * calls [dispatch] when it observes a 401; the host (Android `AuthPlugin`,
 * future iOS equivalent) wires an [emitter] that forwards the event to
 * the Flutter side over an `EventChannel`.
 *
 * The emitter is mutable so the bridge can install it lazily on
 * `EventChannel.onListen` and clear it on `onCancel`. atomicfu guarantees
 * visibility of the update across interceptor / response threads.
 */
class UnauthorizedDispatcher {
    private val emitter = atomic<(() -> Unit)?>(null)

    fun setEmitter(f: (() -> Unit)?) {
        emitter.value = f
    }

    fun dispatch() {
        emitter.value?.invoke()
    }
}

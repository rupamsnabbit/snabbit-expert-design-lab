package com.snabbit.runner.shared.core.deeplink

import kotlinx.atomicfu.atomic

/**
 * Koin-resolvable single-instance dispatcher for resolved AppsFlyer OneLink
 * (Unified Deep Linking) params. Mirrors
 * [com.snabbit.runner.shared.core.network.UnauthorizedDispatcher].
 *
 * The Android AppsFlyer provider's UDL listener calls [dispatch] with the raw
 * param map (`deep_link_value`, `deep_link_sub1`, `deep_link_sub2`,
 * `is_deferred`) on a `FOUND` result. The host
 * (`DeeplinkPlugin`) installs an [emitter] on `EventChannel.onListen` to
 * forward params to Flutter, and clears it on `onCancel`.
 *
 * Cold-start race: UDL can resolve before Dart has attached the event stream.
 * When no emitter is installed at [dispatch] time the params are retained in
 * [pending] so the Dart side can pull them once via [consumePending]
 * (`getInitialDeeplink`). atomicfu guarantees cross-thread visibility — UDL
 * callbacks land on the main looper while the bridge attaches from the
 * platform thread.
 */
class DeeplinkDispatcher {
    private val emitter = atomic<((Map<String, String?>) -> Unit)?>(null)
    private val pending = atomic<Map<String, String?>?>(null)

    fun setEmitter(f: ((Map<String, String?>) -> Unit)?) {
        emitter.value = f
    }

    /**
     * Forward [params] to the Dart listener if one is attached; otherwise
     * retain them for the cold-start [consumePending] drain. Retaining only
     * when there's no emitter prevents a param map being delivered twice
     * (once via the stream, once via getInitialDeeplink).
     */
    fun dispatch(params: Map<String, String?>) {
        val e = emitter.value
        if (e != null) {
            e(params)
        } else {
            pending.value = params
        }
    }

    /** Returns and clears any params retained before a listener attached. */
    fun consumePending(): Map<String, String?>? = pending.getAndSet(null)
}

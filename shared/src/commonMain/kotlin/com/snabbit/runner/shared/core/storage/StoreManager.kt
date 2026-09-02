package com.snabbit.runner.shared.core.storage

/**
 * Typed, domain-aware access to all encrypted values used by the network
 * stack. SnabbitHttpClient and feature repositories depend on this, NOT on
 * [EncryptedStore] directly — adding a new persisted slot (sessionId,
 * userId, …) is a method addition here, not a new class.
 *
 * Implementations are dual-layer: a MutableStateFlow holds the in-memory
 * value (single volatile read on the interceptor hot path) backed by an
 * [EncryptedStore] for persistence across process death.
 *
 * Reads that the request hot path uses ([tokenSnapshot]) are non-suspending
 * because they read from the in-memory flow — no I/O. Writes ([pushToken],
 * [clearToken]) and the cold-start [hydrateAll] are suspending because the
 * backing store is disk-bound.
 *
 * See KMP_NETWORK_MODULE_LLD §11.3.
 */
interface StoreManager {
    /** Restore all persisted values from encrypted storage into in-memory flows. */
    suspend fun hydrateAll()

    // -- Token --
    fun tokenSnapshot(): String?

    /**
     * Suspends until the token's value is definitively known — restored by
     * [hydrateAll] on cold start, or set explicitly by [pushToken]/[clearToken] —
     * then returns it. Use on cold-start paths (e.g. an overlay Accept from a
     * force-killed process) where a request can outrace hydration: [tokenSnapshot]
     * would return null and the request would go out unauthenticated. Returns
     * null once hydrated for a logged-out user.
     */
    suspend fun awaitToken(): String?

    suspend fun pushToken(token: String?)
    suspend fun clearToken()
}

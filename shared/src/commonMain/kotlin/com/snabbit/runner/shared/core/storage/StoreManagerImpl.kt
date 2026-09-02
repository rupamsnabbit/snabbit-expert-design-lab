package com.snabbit.runner.shared.core.storage

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first

/**
 * Dual-layer [StoreManager] implementation (§11.4). MutableStateFlow holds
 * the live in-memory value — the interceptor hot path reads it with a
 * single volatile load. [EncryptedStore] backs persistence; writes update
 * both layers (in-memory first for immediate visibility to the hot path,
 * then disk via the suspending store).
 *
 * Process-death recovery flow: process restart → Koin reconstructs this
 * instance with empty flows → [hydrateAll] reads persisted values into
 * the flows → first HTTP call already has the token.
 */
class StoreManagerImpl(private val store: EncryptedStore) : StoreManager {

    private val _token = MutableStateFlow<String?>(null)

    // Opens once the token's value is definitively known — either restored by
    // [hydrateAll] on cold start, or set explicitly by [pushToken]/[clearToken].
    // [awaitToken] gates on this so a request fired before hydration completes
    // (e.g. an overlay Accept from a force-killed process) waits for the real
    // token instead of racing hydrate and going out unauthenticated.
    private val hydrated = MutableStateFlow(false)

    override suspend fun hydrateAll() {
        try {
            // Single disk snapshot covering every persisted key — adding a key
            // means extending KEYS_TO_HYDRATE, not adding another disk read.
            val snapshot = store.getAll(KEYS_TO_HYDRATE)
            snapshot[Keys.BEARER]?.takeIf { it.isNotBlank() }?.let {
                _token.value = it
            }
            // Future: sessionId, userId, etc.
        } finally {
            // Open the gate even if the disk read threw (corrupt store / Tink
            // failure) so awaitToken() callers can't wedge forever — they fall
            // back to whatever _token holds (null for a fresh/failed restore).
            hydrated.value = true
        }
    }

    override fun tokenSnapshot(): String? = _token.value

    override suspend fun awaitToken(): String? {
        hydrated.first { it }
        return _token.value
    }

    override suspend fun pushToken(token: String?) {
        val prev = _token.value
        _token.value = token
        // An explicit set makes the token definitive — open the awaitToken()
        // gate so a caller that set the token before hydrateAll ran won't block.
        hydrated.value = true
        try {
            if (token != null) {
                store.putString(Keys.BEARER, token)
            } else {
                store.delete(Keys.BEARER)
            }
        } catch (e: Exception) {
            // Disk write failed — revert the optimistic in-memory update so a
            // process restart doesn't resurrect a token we thought we cleared
            // (or persist a token we thought was written).
            _token.value = prev
            throw e
        }
    }

    override suspend fun clearToken() {
        val prev = _token.value
        _token.value = null
        hydrated.value = true
        try {
            store.delete(Keys.BEARER)
        } catch (e: Exception) {
            _token.value = prev
            throw e
        }
    }

    private object Keys {
        const val BEARER = "bearer_token"
        // const val SESSION_ID = "session_id"
        // const val USER_ID = "user_id"
    }

    private companion object {
        val KEYS_TO_HYDRATE = setOf(Keys.BEARER)
    }
}

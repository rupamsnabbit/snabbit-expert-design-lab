package com.snabbit.runner.shared.core.camera

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Optional synchronous mirror of the registry's token→path map, for a consumer
 * that must resolve a path WITHOUT suspending — the Android `WebViewAssetLoader`
 * callback runs on a background worker thread and cannot call the suspend
 * [CaptureRegistry.resolve]. The registry owns the lifecycle: it calls [put] on
 * register and [remove] on eviction/expiry, so there is a single source of truth
 * (the mirror can't drift from the registry). Implementations MUST be thread-safe.
 */
interface CaptureIndex {
    fun put(token: String, filePath: String)
    fun remove(token: String)
}

/**
 * In-memory registry of captured media, keyed by opaque tokens with
 * automatic TTL-based expiry.
 *
 * Ported from Flutter's `capture_registry.dart`. Key differences:
 * - **Thread-safe:** Uses [Mutex] instead of relying on Dart's
 *   single-threaded model.
 * - **Coroutine-based sweep:** Replaces `Timer.periodic` with a
 *   coroutine `delay()` loop scoped to [sweepScope].
 * - **Unguessable tokens:** [generateToken] draws from a per-platform CSPRNG.
 *
 * Captures are registered after the camera writes a file to the
 * dedicated temp directory, and resolved by the asset-loader path
 * handler when the WebView fetches the image/video URL.
 *
 * @param index optional synchronous mirror ([CaptureIndex]) kept in lock-step
 *   with the internal map for the WebView asset-loader's non-suspending lookup.
 */
class CaptureRegistry(
    private val sweepScope: CoroutineScope,
    private val defaultTtlMs: Long = DEFAULT_TTL_MS,
    private val sweepIntervalMs: Long = SWEEP_INTERVAL_MS,
    private val onDeleteFile: suspend (String) -> Unit = {},
    private val index: CaptureIndex? = null,
    private val clock: () -> Long = { currentTimeMillis() },
) {
    private val mutex = Mutex()
    private val entries = mutableMapOf<String, CaptureEntry>()
    private var sweepRunning = false

    /**
     * Registers a file path and returns the opaque token the WebView
     * can use to fetch the media via the asset-loader URL.
     *
     * If [token] is provided it is used as-is; otherwise one is generated
     * from the platform CSPRNG.
     */
    suspend fun register(
        filePath: String,
        token: String? = null,
        ttlMs: Long = defaultTtlMs,
    ): String {
        val key = token ?: generateToken()
        val expiresAt = clock() + ttlMs
        mutex.withLock {
            entries[key] = CaptureEntry(filePath, expiresAt)
            index?.put(key, filePath)
            ensureSweepRunning()
        }
        return key
    }

    /**
     * Returns the file path for [token] if it is still valid, or `null`
     * if the token is unknown or expired. Expired entries are evicted
     * eagerly — the entry is removed under the lock and its backing file
     * deleted *after* the lock is released (see [ensureSweepRunning]).
     */
    suspend fun resolve(token: String): String? {
        val expiredPath = mutex.withLock {
            val entry = entries[token] ?: return null
            if (clock() <= entry.expiresAt) return entry.filePath
            // Expired — evict the entry now, delete its file after unlocking.
            entries.remove(token)
            index?.remove(token)
            entry.filePath
        }
        safeDeleteFile(expiredPath)
        return null
    }

    /**
     * Explicitly evicts [token] — removes the entry and deletes the backing
     * file (outside the lock). No-op if the token is unknown.
     */
    suspend fun evict(token: String) {
        val path = mutex.withLock {
            val entry = entries.remove(token) ?: return
            index?.remove(token)
            entry.filePath
        }
        safeDeleteFile(path)
    }

    /** Returns the number of currently registered entries. */
    suspend fun size(): Int = mutex.withLock { entries.size }

    // ── Private helpers ──────────────────────────────────────────

    private fun ensureSweepRunning() {
        if (sweepRunning) return
        sweepRunning = true
        sweepScope.launch {
            while (true) {
                delay(sweepIntervalMs)
                val (expiredPaths, idle) = mutex.withLock {
                    val now = clock()
                    val expired = entries.filterValues { now > it.expiresAt }
                    expired.keys.forEach { key ->
                        entries.remove(key)
                        index?.remove(key)
                    }
                    val paths = expired.values.map { it.filePath }
                    if (entries.isEmpty()) {
                        sweepRunning = false
                        paths to true
                    } else {
                        paths to false
                    }
                }
                // Delete backing files OUTSIDE the lock: onDeleteFile is suspend I/O,
                // and holding the (non-reentrant) mutex across it would serialize the
                // capture hot path — and deadlock if the callback re-entered the registry.
                expiredPaths.forEach { safeDeleteFile(it) }
                if (idle) break
            }
        }
    }

    private suspend fun safeDeleteFile(filePath: String) {
        try {
            onDeleteFile(filePath)
        } catch (_: Throwable) {
            // Best-effort cleanup — file may already be gone.
        }
    }

    private data class CaptureEntry(
        val filePath: String,
        val expiresAt: Long,
    )

    companion object {
        const val DEFAULT_TTL_MS = 15L * 60 * 1000 // 15 minutes
        const val SWEEP_INTERVAL_MS = 5L * 60 * 1000 // 5 minutes

        /** Photo size limit: 10 MB */
        const val MAX_PHOTO_SIZE_BYTES = 10L * 1024 * 1024

        /** Video size limit: 50 MB */
        const val MAX_VIDEO_SIZE_BYTES = 50L * 1024 * 1024

        /** 128 bits of entropy per token. */
        private const val TOKEN_BYTES = 16

        /**
         * Opaque, unguessable capture token from the platform CSPRNG, hex-encoded.
         * The prior `"${millis}_${counter}"` scheme was enumerable — combined with
         * the WebView asset loader that would let crafted web content brute-force
         * other captures' URLs.
         */
        internal fun generateToken(): String =
            secureRandomBytes(TOKEN_BYTES).joinToString("") {
                ((it.toInt() and 0xFF) + 0x100).toString(16).substring(1)
            }
    }
}

/** Platform-agnostic epoch millis. */
internal expect fun currentTimeMillis(): Long

/** Fills and returns [count] bytes from the platform cryptographic RNG. */
internal expect fun secureRandomBytes(count: Int): ByteArray

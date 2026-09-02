package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.storage.PreferenceStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * Wire/environment settings shared by every HTTP call (§11.1):
 *  - `baseUrl`       — scheme + host + optional path prefix
 *  - `versionCode`   — value of the `x-version-code` header
 *  - `onboardingUrl` — base for the onboarding host (a *different* host than
 *    [baseUrl]); used by the few onboarding-service calls, e.g. PAN update. May
 *    be blank if Dart hasn't pushed it (older push) — callers guard on that.
 *
 * `baseUrl`/`versionCode` are non-secret; the last-pushed pair is persisted
 * (unencrypted, via [PreferenceStorage]) so [NetworkConfigStore.seedFromCache]
 * can restore it on a cold start before Dart pushes a fresh one.
 */
data class NetworkConfig(
    val baseUrl: String,
    val versionCode: String,
    val onboardingUrl: String = "",
    /** Pre-formatted "App version X+Y" label for the Profile footer (Dart-computed). */
    val appVersion: String = "",
    /** True on the production environment — the Profile footer hides the endpoint line then. */
    val isProd: Boolean = true,
)

/**
 * Holds the current [NetworkConfig] and owns the init gate that blocks
 * outgoing HTTP until Dart has pushed a non-blank baseUrl.
 *
 * Single-instance, owned by Koin (`coreModule`). The interceptor chain
 * reads `snapshot()` on the hot path; `SnabbitHttpClient.execute()` calls
 * `awaitReady()` once per request before building the URL.
 */
class NetworkConfigStore(
    private val preferenceStorage: PreferenceStorage? = null,
    dispatchers: AppDispatchers? = null,
) {
    private val _config = MutableStateFlow<NetworkConfig?>(null)

    // Fire-and-forget scope for persisting each pushed config (only when a
    // store is wired). Process-lived; SupervisorJob so a failed write can't
    // tear it down. Persistence is opt-in — a store built without deps (some
    // network tests, iOS until wired) simply doesn't persist or seed.
    private val persistScope: CoroutineScope? =
        dispatchers?.let { CoroutineScope(SupervisorJob() + it.io) }

    /** Suspends until baseUrl has been pushed and is non-blank. */
    suspend fun awaitReady(): NetworkConfig =
        _config.first { it != null && it.baseUrl.isNotBlank() }!!

    /** Non-suspending peek — returns null if config has never been pushed. */
    fun snapshot(): NetworkConfig? = _config.value

    /**
     * Push a new config. Idempotent — calling repeatedly with the same
     * values is a no-op as far as observers are concerned. When a
     * [PreferenceStorage] is wired, only the baseUrl/versionCode pair is
     * persisted (fire-and-forget) so a future cold start can [seedFromCache]
     * before Dart re-pushes; onboardingUrl/appVersion/isProd live in memory
     * only and are re-pushed by Dart on every launch.
     */
    fun pushNetworkConfig(
        baseUrl: String,
        versionCode: String,
        onboardingUrl: String = "",
        appVersion: String = "",
        isProd: Boolean = true,
    ) {
        val config = NetworkConfig(
            baseUrl.trim(),
            versionCode.trim(),
            onboardingUrl.trim(),
            appVersion.trim(),
            isProd,
        )
        _config.value = config
        val storage = preferenceStorage ?: return
        if (config.baseUrl.isBlank()) return
        persistScope?.launch {
            storage.putString(KEY_BASE_URL, config.baseUrl)
            storage.putString(KEY_VERSION_CODE, config.versionCode)
            // Persisted with the pair: a seeded config that silently defaulted isProd=true would
            // claim prod on a staging build until Dart re-pushes.
            storage.putString(KEY_IS_PROD, config.isProd.toString())
        }
    }

    /**
     * Cold-start seed (Phase B): if nothing has been pushed yet, restore the
     * last-persisted baseUrl/versionCode so KMP HTTP can proceed on a
     * force-killed FCM wake — before the Flutter engine attaches and Dart
     * pushes a fresh config. No-op without a wired store, if a config already
     * landed, or if nothing was persisted.
     */
    suspend fun seedFromCache() {
        if (_config.value != null) return
        val storage = preferenceStorage ?: return
        val baseUrl = storage.getString(KEY_BASE_URL)?.takeIf { it.isNotBlank() } ?: return
        val versionCode = storage.getString(KEY_VERSION_CODE).orEmpty()
        // Absent (install predating the isProd persist) → true, the historical default, so an
        // upgrading install behaves exactly as before.
        val isProd = storage.getString(KEY_IS_PROD)?.toBooleanStrictOrNull() ?: true
        if (_config.value == null) {
            _config.value = NetworkConfig(baseUrl, versionCode, isProd = isProd)
        }
    }

    private companion object {
        const val KEY_BASE_URL = "net_base_url"
        const val KEY_VERSION_CODE = "net_version_code"
        const val KEY_IS_PROD = "net_is_prod"
    }
}

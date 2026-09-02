package com.snabbit.runner.shared.core.config

/**
 * Bridge seam to the Flutter-owned Firebase Remote Config (D-6). Firebase RC is
 * configured + fetched on the Flutter side (`RemoteConfigService`); KMP reads the
 * cached values through this seam — mirroring [ProfileGateway]. The channel-backed
 * impl is wired in `:app`; until then [DefaultRemoteConfigGateway] returns the
 * caller's fallback. `suspend` + main-safe.
 */
interface RemoteConfigGateway {
    suspend fun getBoolean(key: String, default: Boolean): Boolean
    suspend fun getInt(key: String, default: Int): Int
    suspend fun getDouble(key: String, default: Double): Double
    suspend fun getString(key: String, default: String): String
    suspend fun getStringList(key: String, default: List<String>): List<String>

    /**
     * Fetch + activate the latest RC values on the native SDK, in one call. Returns true when the
     * activated config changed. Bridged from the platform SDK's callback API (Android `Task<Boolean>`,
     * iOS `fetchAndActivate(completionHandler:)`). Fail-safe — a fetch failure resolves to false, never
     * throws. Called once at launch from `KmpBootstrap` (fire-and-forget).
     */
    suspend fun fetchAndActivate(): Boolean
}

/** No-RC fallback impl — every key resolves to the caller's default. Replaced by the `:app` bridge. */
class DefaultRemoteConfigGateway : RemoteConfigGateway {
    override suspend fun getBoolean(key: String, default: Boolean) = default
    override suspend fun getInt(key: String, default: Int) = default
    override suspend fun getDouble(key: String, default: Double) = default
    override suspend fun getString(key: String, default: String) = default
    override suspend fun getStringList(key: String, default: List<String>) = default

    // No native SDK behind this fallback — nothing to fetch.
    override suspend fun fetchAndActivate() = false
}

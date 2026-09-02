package com.snabbit.runner.shared.features.kavach.shield.data.store

import android.app.Application
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import kotlinx.coroutines.withContext

// Documented Flutter APK layout: assets ship under `assets/flutter_assets/<path>` (AssetManager root is
// the APK `assets/`, so the key is `flutter_assets/<path>`). RC key lets ops repoint the base (#2).
internal const val SHIELD_FLUTTER_ASSETS_PREFIX = "flutter_assets"
internal const val RC_SHIELD_ASSET_PREFIX = "expert_shield_android_asset_prefix"

/**
 * Ordered, de-duped AssetManager candidate keys for a Flutter asset (#1 prefix-fallback):
 * RC-override prefix → documented `flutter_assets` → raw path. Pure (no AssetManager) so the ordering
 * + de-dup + prefix-join is unit-testable as a regression guard.
 */
internal fun shieldAssetCandidateKeys(assetPath: String, rcPrefix: String): List<String> =
    listOf(rcPrefix, SHIELD_FLUTTER_ASSETS_PREFIX, "")
        .distinct()
        .map { prefix -> if (prefix.isEmpty()) assetPath else "$prefix/$assetPath" }

/**
 * Reads Flutter-bundled assets straight from the APK via `AssetManager.open()` (bytes decompress
 * transparently — no mmap, so APK compression is a non-issue).
 *
 * Resilient, single-sourced (no fallback copy in the APK — ECPO-916):
 *  - #1 prefix-fallback: try each [shieldAssetCandidateKeys] candidate until one opens.
 *  - #2 RC override: [RC_SHIELD_ASSET_PREFIX] repoints the base prefix WITHOUT an app update if Flutter's
 *    asset layout ever shifts. Defaults to `flutter_assets`.
 *
 * Off-main; empty bytes on a total miss so callers degrade non-fatally (ML off, siren silent, etc.).
 */
internal class AndroidShieldAssetReader(
    private val app: Application,
    private val remoteConfig: RemoteConfigGateway,
    private val dispatchers: AppDispatchers,
) : ShieldAssetReader {
    override suspend fun read(assetPath: String): ByteArray = withContext(dispatchers.io) {
        val rcPrefix = runCatching { remoteConfig.getString(RC_SHIELD_ASSET_PREFIX, SHIELD_FLUTTER_ASSETS_PREFIX) }
            .getOrDefault(SHIELD_FLUTTER_ASSETS_PREFIX)
        for (key in shieldAssetCandidateKeys(assetPath, rcPrefix)) {
            runCatching { app.assets.open(key).use { it.readBytes() } }.getOrNull()?.let { return@withContext it }
        }
        ByteArray(0)
    }
}

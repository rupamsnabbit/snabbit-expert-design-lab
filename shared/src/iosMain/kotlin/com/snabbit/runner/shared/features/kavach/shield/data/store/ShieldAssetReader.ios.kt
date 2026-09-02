package com.snabbit.runner.shared.features.kavach.shield.data.store

import com.snabbit.runner.shared.core.AppDispatchers
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.convert
import kotlinx.cinterop.usePinned
import kotlinx.coroutines.withContext
import platform.Foundation.NSData
import platform.Foundation.dataWithContentsOfFile
import platform.posix.memcpy

/**
 * Swift-facing seam for reading Flutter-bundled assets on iOS. The KMP framework can't call Flutter's
 * `lookupKey(forAsset:)` itself (no engine reference), so the host resolves a Flutter asset path (e.g.
 * "assets/ml-models/yamnet.tflite") to its absolute on-disk bundle path; KMP reads the file. Host-injected
 * via `KmpBootstrap.initialize` (mirrors `IosRemoteConfigProvider` + the D-17 detector seams).
 */
interface IosFlutterAssetProvider {
    // `assetPath` (not `path`) keeps the generated Swift protocol label clean. Null when unresolvable.
    fun resolvePath(assetPath: String): String?
}

/** Set once by the iOS host (KmpBootstrap) before Koin starts. */
private var hostProvider: IosFlutterAssetProvider? = null

internal fun setIosFlutterAssetProvider(provider: IosFlutterAssetProvider) {
    hostProvider = provider
}

internal fun iosShieldAssetReader(dispatchers: AppDispatchers): ShieldAssetReader =
    IosShieldAssetReader(hostProvider, dispatchers)

/** Reads the file the host resolved for the Flutter asset. Empty bytes when the host is absent/unresolved. */
@OptIn(ExperimentalForeignApi::class)
internal class IosShieldAssetReader(
    private val provider: IosFlutterAssetProvider?,
    private val dispatchers: AppDispatchers,
) : ShieldAssetReader {
    override suspend fun read(assetPath: String): ByteArray = withContext(dispatchers.default) {
        val filePath = provider?.resolvePath(assetPath) ?: return@withContext ByteArray(0)
        val data = NSData.dataWithContentsOfFile(filePath) ?: return@withContext ByteArray(0)
        val length = data.length.toInt()
        if (length == 0) return@withContext ByteArray(0)
        ByteArray(length).also { out ->
            out.usePinned { pinned -> memcpy(pinned.addressOf(0), data.bytes, data.length.convert()) }
        }
    }
}

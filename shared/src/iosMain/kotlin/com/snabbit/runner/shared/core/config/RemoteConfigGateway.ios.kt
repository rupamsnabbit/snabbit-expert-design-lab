package com.snabbit.runner.shared.core.config

import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * iOS Remote Config wiring (B-native). The Firebase iOS SDK is Obj-C/Swift and the KMP framework
 * deliberately ships without CocoaPods/cinterop — so the iOS host supplies an [IosRemoteConfigProvider]
 * (Swift, reading `FIRRemoteConfig`) via `KmpBootstrap.initialize`, mirroring the D-17 detector seam.
 * Until the host sets one, the gateway falls back to defaults (fail-safe — every key → its default).
 */
private var hostProvider: IosRemoteConfigProvider? = null

/** Set once by the iOS host (KmpBootstrap) before Koin starts. */
internal fun setIosRemoteConfigProvider(provider: IosRemoteConfigProvider) {
    hostProvider = provider
}

actual fun remoteConfigGateway(): RemoteConfigGateway =
    hostProvider?.let { IosRemoteConfigGateway(it) } ?: DefaultRemoteConfigGateway()

/** Adapts the host-provided (Swift, sync) [IosRemoteConfigProvider] to the suspend [RemoteConfigGateway]. */
internal class IosRemoteConfigGateway(private val provider: IosRemoteConfigProvider) : RemoteConfigGateway {
    override suspend fun getBoolean(key: String, default: Boolean) = provider.getBoolean(key, default)
    override suspend fun getInt(key: String, default: Int) = provider.getInt(key, default)
    override suspend fun getDouble(key: String, default: Double) = provider.getDouble(key, default)
    override suspend fun getString(key: String, default: String) = provider.getString(key, default)
    override suspend fun getStringList(key: String, default: List<String>) = provider.getStringList(key, default)

    // Bridge the host's callback fetch to suspend (mirrors the Android Task bridge). Fail-safe by
    // contract: the Swift host maps a fetch error to onComplete(false), so this never throws at launch.
    override suspend fun fetchAndActivate(): Boolean = suspendCancellableCoroutine { cont ->
        provider.fetchAndActivate { activated -> if (cont.isActive) cont.resume(activated) }
    }
}

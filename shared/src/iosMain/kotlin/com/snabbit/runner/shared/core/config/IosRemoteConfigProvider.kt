package com.snabbit.runner.shared.core.config

/**
 * Swift-facing seam for iOS Remote Config: the host implements this over the official Firebase iOS
 * SDK (`FIRRemoteConfig`) and hands it to `KmpBootstrap.initialize` — so the KMP framework stays free
 * of Firebase/CocoaPods (mirrors the D-17 VoiceDetector/AudioClassifier host-injection).
 *
 * Sync getters (FIRRemoteConfig reads are synchronous). Each MUST return the caller's [default] for an
 * unset key (Firebase source `.static`) so the shipped call-site defaults are preserved — 1:1 with the
 * Android [RemoteConfigGateway] impl.
 */
interface IosRemoteConfigProvider {
    // `defaultValue` (not `default`) — `default` is a Swift keyword; this keeps the generated Swift
    // protocol label clean for the host impl.
    fun getBoolean(key: String, defaultValue: Boolean): Boolean
    fun getInt(key: String, defaultValue: Int): Int
    fun getDouble(key: String, defaultValue: Double): Double
    fun getString(key: String, defaultValue: String): String
    fun getStringList(key: String, defaultValue: List<String>): List<String>

    // Async (FIRRemoteConfig `fetchAndActivate(completionHandler:)` is callback-based, unlike the sync
    // getters). Callback-shaped rather than suspend so the Swift host stays a plain completion handler;
    // [IosRemoteConfigGateway] bridges it to suspend. `onComplete(true)` when the activated config changed.
    fun fetchAndActivate(onComplete: (Boolean) -> Unit)
}

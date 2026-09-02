import Foundation
import FirebaseRemoteConfig
import Shared  // KMP framework — the IosRemoteConfigProvider seam.

/// Swift impl of the KMP `IosRemoteConfigProvider` seam (B-native Remote Config on iOS).
///
/// Reads live Firebase RC via the official iOS SDK — no Flutter/Pigeon bridge. Mirrors the Android
/// `FirebaseRemoteConfigGateway`: an unset key (source `.static`) returns the caller's default so the
/// shipped call-site defaults are preserved; string lists are JSON-array strings (1:1 with Flutter's
/// `json.decode`).
///
/// ⚠️ On-device verification (this file is not built in the KMP env):
///  - Confirm the method labels against the generated `Shared-Swift.h` (`IosRemoteConfigProvider`),
///    same as the `SileroVoiceDetector` / `YamnetAudioClassifier` detector protocols.
///  - Requires the `FirebaseRemoteConfig` pod. It is linked transitively via FlutterFire
///    (`firebase_remote_config`); if `import FirebaseRemoteConfig` doesn't resolve, add
///    `pod 'FirebaseRemoteConfig'` to `ios/Podfile`.
///  - `RemoteConfigValue.stringValue` is non-optional on current Firebase iOS; if your pinned SDK
///    exposes it as optional, coalesce with `?? ""`.
final class FirebaseRemoteConfigProvider: IosRemoteConfigProvider {

    // Lazy per call: the default FirebaseApp is configured by FlutterFire (Dart `Firebase.initializeApp`,
    // which runs after `didFinishLaunching`) — so never touch RC at init, only on first read (which
    // happens later, during a shield flow).
    private var rc: RemoteConfig { RemoteConfig.remoteConfig() }

    func getBoolean(key: String, defaultValue: Bool) -> Bool {
        let value = rc.configValue(forKey: key)
        return value.source == .static ? defaultValue : value.boolValue
    }

    // Parse stringValue (not numberValue): numberValue coerces a malformed/non-numeric remote value to
    // 0, which would silently override a call-site default (e.g. a bad yamnet threshold → 0 → SOS flood).
    // Mirrors Android's asLong/asDouble throw→default fallback.
    func getInt(key: String, defaultValue: Int32) -> Int32 {
        let value = rc.configValue(forKey: key)
        guard value.source != .static, let n = Int32(value.stringValue) else { return defaultValue }
        return n
    }

    func getDouble(key: String, defaultValue: Double) -> Double {
        let value = rc.configValue(forKey: key)
        guard value.source != .static, let n = Double(value.stringValue) else { return defaultValue }
        return n
    }

    func getString(key: String, defaultValue: String) -> String {
        let value = rc.configValue(forKey: key)
        return value.source == .static ? defaultValue : value.stringValue
    }

    func getStringList(key: String, defaultValue: [String]) -> [String] {
        let value = rc.configValue(forKey: key)
        guard value.source != .static,
              let data = value.stringValue.data(using: .utf8),
              let list = try? JSONDecoder().decode([String].self, from: data)
        else { return defaultValue }
        return list
    }

    /// Fetch + activate in one call (KMP bridges this callback to a suspend). `onComplete(true)` when the
    /// activated config changed. Fail-safe: any error → `onComplete(false)` so a launch fetch never throws.
    ///
    /// ⚠️ On-device: the KMP function-type param boxes to `KotlinBoolean` in the generated header — hence
    ///    `KotlinBoolean(bool:)`. If the generated protocol declares a plain `Bool` closure, drop the box.
    func fetchAndActivate(onComplete: @escaping (KotlinBoolean) -> Void) {
        rc.fetchAndActivate { status, _ in
            onComplete(KotlinBoolean(bool: status == .successFetchedFromRemote))
        }
    }
}

import Foundation
import Flutter
import Shared  // KMP framework — the IosFlutterAssetProvider seam.

/// Swift impl of the KMP `IosFlutterAssetProvider` seam (ECPO-916 single-sourcing).
///
/// Resolves a Flutter asset path (e.g. "assets/ml-models/yamnet.tflite") to its absolute on-disk path
/// in the app bundle, so the KMP Kavach reads the SAME bundled file the Flutter shield uses — one copy,
/// not a duplicate under composeResources. Native only — no method channel / Dart round-trip.
///
/// Wire it in `AppDelegate` alongside the other seams:
///   KmpBootstrap.shared.initialize(
///     voiceDetector: …, audioClassifier: …, remoteConfig: …,
///     flutterAssets: FlutterShieldAssetProvider(), crashReporter: …)
///
/// ⚠️ On-device verification (this file is not built in the KMP env):
///  - Confirm the protocol + label against the generated `Shared-Swift.h` (`IosFlutterAssetProvider`),
///    same as `FirebaseRemoteConfigProvider` / the Silero·YAMNet detector protocols.
///  - `FlutterDartProject.lookupKey(forAsset:)` returns the flutter_assets-relative key; the file ships
///    in the app's main bundle. If `path(forResource:ofType:)` returns nil, the assets live under a
///    subdirectory — resolve via `Bundle.main.path(forResource: key, ofType: nil, inDirectory: "flutter_assets")`
///    or `Bundle.main.url(forResource:…)`. KMP falls back to ML-off (non-fatal) on a nil/miss.
final class FlutterShieldAssetProvider: IosFlutterAssetProvider {
    func resolvePath(assetPath: String) -> String? {
        let key = FlutterDartProject.lookupKey(forAsset: assetPath)
        // Documented Flutter pattern is bundle-root (`path(forResource: key, ofType: nil)`) — the key is
        // bundle-relative (Android's includes the flutter_assets prefix). Try that first, then fall back to
        // the flutter_assets subdir in case this build ships assets there with a flutter_assets-relative key.
        // Covers both layouts without betting on one; a blind `inDirectory` swap would double-prefix if the
        // key already carries it. ⚠️ still confirm the resolved layout on-device.
        return Bundle.main.path(forResource: key, ofType: nil)
            ?? Bundle.main.path(forResource: key, ofType: nil, inDirectory: "flutter_assets")
            ?? Bundle.main.path(forResource: assetPath, ofType: nil, inDirectory: "flutter_assets")
    }
}

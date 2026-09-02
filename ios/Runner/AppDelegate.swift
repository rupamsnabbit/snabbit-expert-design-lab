import Flutter
import UIKit
import Shared  // KMP framework — KmpBootstrap + the shield detector protocols.

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Held so the Swift detector instances aren't released after handing them to the Koin graph.
  private let voiceDetector = SileroVoiceDetector()
  private let audioClassifier = YamnetAudioClassifier()
  private let remoteConfig = FirebaseRemoteConfigProvider()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Mirror of Android's SnabbitRunnerApplication.onCreate: start the KMP graph once, injecting
    // the Swift ML detectors (D-17). Fail-open — the KMP side guards re-entry and swallows errors.
    // ⚠️ Confirm `KmpBootstrap.shared` + the crashReporter closure shape against generated Shared-Swift.h.
    KmpBootstrap.shared.initialize(
      voiceDetector: voiceDetector,
      audioClassifier: audioClassifier,
      remoteConfig: remoteConfig,
      crashReporter: { (throwable: KotlinThrowable, meta: [String: String]) -> KotlinUnit in
        NSLog("Kavach:KMP crash \(meta): \(throwable.message ?? "unknown")")
        return KotlinUnit()
      }
    )

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

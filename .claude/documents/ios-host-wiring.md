# iOS Host Wiring — KMP Shared framework + Swift ML detectors

Status of the Flutter iOS Runner ↔ KMP `:shared` integration. **Everything in "Verified here"
is committed + gate-green. Everything under "Xcode-gated" is authored-as-reference and MUST be
built/verified on a full-Xcode machine** — this repo builds iOS Kotlin (`compileKotlinIosArm64`)
but cannot link a framework or build Swift (CLT-only: `xcrun` exit 72).

## Verified here (committed, gates green)

| Piece | File | Gate |
|-------|------|------|
| Host detector-injection seam | `shared/…/core/KmpBootstrap.kt` (iOS) | `compileKotlinIosArm64` |
| `:shield` exported to Swift | `shared/build.gradle.kts` (`api` + `export`) | compile |
| Step 6 model-asset resolution | `shared/…/kavach/data/ModelAssetResolver.*` + `ShieldConfigFactory` | `testDebugUnitTest` + iOS compile |
| Models bundled (Compose Resources) | `shared/…/composeResources/files/{silero_vad.onnx,yamnet.tflite,yamnet_labels.txt}` | — |
| XCFramework assembly registered | `assembleSharedXCFramework` | config-valid (assembly is xcrun-gated) |

## Xcode-gated (authored reference — build + verify on a full-Xcode machine)

### 1. Framework integration — SPM local package (NOT CocoaPods)
Rationale (official): CocoaPods is maintenance-mode, trunk read-only **Dec 2 2026**
([blog.cocoapods.org](https://blog.cocoapods.org/CocoaPods-Specs-Repo/)); Flutter defaults to SPM
since **3.44** and documents adding a local Swift package to the Runner
([docs.flutter.dev](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers));
KMP documents the local-Swift-package path
([kotlinlang.org](https://kotlinlang.org/docs/multiplatform/multiplatform-spm-local-integration.html)).
**Confirm the team's Flutter version is ≥ 3.44.**

Steps:
1. Build the artifact: `./android/gradlew -p android :shared:assembleSharedXCFramework`
   → `shared/build/XCFrameworks/release/Shared.xcframework`.
2. The local Swift package is **already checked in** at [`ios/SharedKMP/Package.swift`](../../ios/SharedKMP/Package.swift)
   (binaryTarget → the xcframework from step 1; platform `.iOS(.v14)`). Nothing to author — just build the xcframework.
3. In Xcode (`ios/Runner.xcworkspace`) → Runner target → **Add Local…** → select `ios/SharedKMP`.
4. (Dev convenience) add a scheme **pre-action** that runs `assembleSharedXCFramework` so the
   framework rebuilds with the app. Alternative approach: `embedAndSignAppleFrameworkForXcode`
   (rebuilds per Xcode build; no checked-in xcframework) — see the KMP SPM-local doc.
- If a **dynamic** framework is required on-device, flip `isStatic = false` in `shared/build.gradle.kts`.
- **⚠ Bump `IPHONEOS_DEPLOYMENT_TARGET` 12.0 → 14** in `Runner.xcodeproj` (all 3 config blocks) — the KMP
  CoreLocation/permission APIs need iOS 14+ and `onnxruntime-objc` needs 13+. Do this in Xcode (not by
  hand-editing `.pbxproj`). The checked-in `Package.swift` already declares `.iOS(.v14)`.

### 2. ML runtime dependencies (add to the Runner target)
Both are official + Swift-consumable in a Flutter iOS app:
- **ONNX Runtime (Silero VAD):** pod/SPM `onnxruntime-objc` — ObjC API via the bridging header
  (`ios/Runner/Runner-Bridging-Header.h` already `#import <onnxruntime.h>`; if the linked build is
  modular, use `import onnxruntime` in `SileroVoiceDetector.swift` instead). [onnxruntime.ai](https://onnxruntime.ai/docs/get-started/with-obj-c.html)
- **TFLite/LiteRT (YAMNet):** `TensorFlowLiteSwift` — native Swift `Interpreter` (`import TensorFlowLite`).
  No separate `LiteRT` pod exists. [developers.google.com/edge/litert/ios](https://developers.google.com/edge/litert/ios/quickstart)

### 3. Model files — Copy Bundle Resources
Step 6 resolves the models from **Compose Resources** (packaged in `Shared.framework`) via
`Res.readBytes` → writes to the iOS Caches dir → returns an absolute path → the Swift detectors'
`loadModel(path)`. **No extra Xcode resource step is needed** as long as the models stay in
`shared/…/composeResources/files/` (they do). The 3 files also remain in `assets/ml-models/` for
Flutter (≈6 MB duplication — accepted tradeoff for a clean KMP asset seam; de-dup is a follow-up).

### 4. Files authored (Swift host + detectors)
| File | Role |
|------|------|
| `ios/Runner/AppDelegate.swift` | Calls `KmpBootstrap.shared.initialize(voiceDetector:audioClassifier:crashReporter:)` (mirror of Android `SnabbitRunnerApplication`). |
| `ios/Runner/Shield/SileroVoiceDetector.swift` | ORT Silero VAD — 1:1 port of `AndroidVoiceDetector`. |
| `ios/Runner/Shield/YamnetAudioClassifier.swift` | TFLite YAMNet — 1:1 port of `AndroidAudioClassifier`. |
| `ios/Runner/Runner-Bridging-Header.h` | `#import <onnxruntime.h>`. |

## ⚠️ Confirm-on-device (interop boundaries authored without a build)
1. **Generated Swift names.** After the first XCFramework build, open `Shared.framework/Headers/
   Shared-Swift.h` and confirm: `KmpBootstrap.shared`, the `VoiceDetector`/`AudioClassifier`
   protocol signatures (`KotlinShortArray`, `Int32`, `[KotlinPair<NSString, KotlinDouble>]`),
   `KotlinDouble(value:)`, and the `crashReporter` closure type (`(KotlinThrowable, [String:String]) -> KotlinUnit`).
   Adjust the Swift to match exactly if the generated spelling differs.
2. **ORT ObjC API.** Confirm `ORTEnv`, `ORTSession(env:modelPath:sessionOptions:)`,
   `ORTValue(tensorData:elementType:shape:)`, `run(withInputs:outputNames:runOptions:)` against the
   linked `onnxruntime-objc` version.
3. **Silero I/O (verified from the model file):** inputs `input`/`state`/`sr`, outputs `output`/`stateN`;
   state `[2,1,128]` f32 threaded across chunks; `sr` shape `[1]` int64. Watch the stateful contract —
   a stateless call or wrong 512-frame size produces garbage.
4. **KotlinShortArray access** is per-element (`.get(index:)`) across the bridge — a known perf cost;
   optimize only if profiling shows it matters.
5. **RC gate.** ML is OFF by default. To exercise end-to-end, enable Firebase RC
   `expert_shield_ml_detection_enabled` (parity: thresholds VAD 0.7 / YAMNet 0.7, topK 7).

## On-device verification checklist
- [ ] `assembleSharedXCFramework` produces `Shared.xcframework`.
- [ ] Runner links `SharedKMP` local package + `onnxruntime-objc` + `TensorFlowLiteSwift`; `flutter build ios` succeeds.
- [ ] App launches → `KmpBootstrap` starts Koin once (no re-entry crash); Keychain hydrate runs.
- [ ] With RC ML enabled: `ModelAssetResolver` writes the 3 files to Caches; detectors' `loadModel` returns true.
- [ ] VAD confidence + YAMNet top-K match Android for the same audio (parity).

// swift-tools-version:5.9
// Local Swift package wrapping the KMP `Shared` XCFramework for the Flutter iOS Runner.
// Build the artifact first: `./android/gradlew -p android :shared:assembleSharedXCFramework`
// (needs full Xcode — xcrun-gated), then in Xcode: Runner target → Add Local… → select this folder.
// The binaryTarget path is relative to THIS Package.swift.
import PackageDescription

let package = Package(
    name: "SharedKMP",
    platforms: [.iOS(.v14)], // matches the Runner deployment target + the KMP CoreLocation/permission APIs (iOS 14+)
    products: [
        .library(name: "SharedKMP", targets: ["Shared"]),
    ],
    targets: [
        .binaryTarget(
            name: "Shared",
            path: "../../shared/build/XCFrameworks/release/Shared.xcframework"
        ),
    ]
)

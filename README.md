# Snabbit Runner App

A Flutter-based mobile application for Android that enables runners to manage deliveries, track earnings, and interact with the Snabbit platform.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Design System](#design-system)
- [Key Features](#key-features)
- [Building the App](#building-the-app)
- [Troubleshooting](#troubleshooting)

## Overview

**Package Name**: `com.snabbit.runner`
**Version**: 2.4.15+157
**Dart SDK**: >=3.4.1 <4.0.0
**Min Android SDK**: 24 (Android 7.0)
**Target Android SDK**: 35 (Android 15)
**Compile Android SDK**: 35

This is an **Android-only** Flutter application despite having the cross-platform capability.

## Design System

For product-design rules, approved components, screen patterns, state coverage, and the new-component brief, see the [Expert App design framework](docs/design/README.md).

## Prerequisites

Before you begin, ensure you have the following installed on your macOS machine:

- **Homebrew** (package manager for macOS)
- **Git** (for cloning the repository)
- Internet connection (for downloading dependencies)

## Development Setup

Follow these steps to set up your development environment:

### 1. Install Flutter SDK

```bash
brew install flutter
```

### 2. Install Java JDK 17

```bash
brew install openjdk@17
```

### 3. Install Android Command Line Tools

```bash
# Create Android SDK directory
mkdir -p ~/Library/Android/sdk/cmdline-tools

# Download command line tools
cd ~/Library/Android/sdk/cmdline-tools
curl -O https://dl.google.com/android/repository/commandlinetools-mac-13114758_latest.zip

# Extract and organize
unzip commandlinetools-mac-13114758_latest.zip
mv cmdline-tools latest
```

### 4. Configure Environment Variables

Add these lines to your `~/.zshrc` (or `~/.bash_profile` if using Bash):

```bash
# Android Development Environment
export ANDROID_HOME=~/Library/Android/sdk
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$PATH"
```

Then reload your shell configuration:

```bash
source ~/.zshrc
```

### 5. Accept Android Licenses

```bash
sdkmanager --licenses
# Type 'y' for each license prompt
```

### 6. Install Required Android SDK Components

```bash
sdkmanager "platform-tools" \
           "platforms;android-35" \
           "platforms;android-34" \
           "platforms;android-36" \
           "build-tools;35.0.0" \
           "build-tools;28.0.3" \
           "ndk;28.2.13676358"
```

### 7. Configure Flutter

```bash
flutter config --android-sdk $ANDROID_HOME
```

### 8. Verify Installation

```bash
flutter doctor
```

You should see checkmarks for:
- Flutter
- Android toolchain
- Chrome (for web development)
- Connected device

### 9. Clone and Setup Project

```bash
# Clone the repository
git clone git@github.com:snabbit-tech/snabbit-runner-app.git
cd snabbit-runner-app

# Install dependencies
flutter pub get
```

### 10. Firebase Configuration

The project includes Firebase integration. The `google-services.json` file is already present in `android/app/`. Ensure you have the correct Firebase configuration for your environment.

## Project Structure

```
snabbit-runner-app/
├── android/              # Android-specific configuration
│   └── app/
│       ├── build.gradle  # Build configuration
│       └── google-services.json
├── assets/               # App assets (images, fonts, sounds)
│   ├── pngs/
│   ├── svgs/
│   ├── gifs/
│   ├── fonts/
│   └── notification_sounds/
├── lib/                  # Main Dart codebase
│   ├── constants/        # App-wide constants
│   ├── effects/          # Visual effects & animations
│   ├── home/             # Home screen modules
│   ├── models/           # Data models
│   ├── pages/            # UI pages/screens
│   ├── payout/           # Payout functionality
│   ├── providers/        # State management (Provider pattern)
│   ├── referrals/        # Referral system
│   ├── services/         # Business logic & API calls
│   ├── utils/            # Helper functions
│   ├── widgets/          # Reusable UI components
│   └── main.dart         # App entry point
├── shared/               # Compose Multiplatform shared module (KMP)
│   └── src/
│       ├── commonMain/   # Shared Kotlin + Compose UI (iOS-compatible)
│       ├── androidMain/  # Android-specific bindings
│       ├── iosMain/      # iOS-specific bindings
│       └── commonTest/   # Shared tests
├── test/                 # Flutter test files
├── pubspec.yaml          # Project dependencies
├── shorebird.yaml        # OTA update configuration
└── README.md             # This file
```

## Key Features

### Technology Stack

- **State Management**: Provider
- **HTTP Client**: Dio & HTTP package
- **Maps**: Google Maps Flutter
- **Location Services**: Geolocator & Location packages
- **Firebase**:
  - Core
  - Crashlytics (crash reporting)
  - Cloud Messaging (push notifications)
  - Remote Config
- **Local Storage**: Shared Preferences
- **PDF Viewing**: Flutter PDF View
- **Background Services**: Flutter Background Service & WorkManager
- **OTA Updates**: Shorebird Code Push
- **Analytics**: CleverTap, Mixpanel, Firebase Analytics
- **UI Components**:
  - Material Design
  - Custom fonts (Metropolis family)
  - SVG support
  - Animations (Flutter Animate)
  - Lottie animations

### App Capabilities

- Real-time location tracking
- Push notifications with custom sounds
- Background service support
- PDF document viewing
- Image capture and upload
- Video playback
- QR code scanning
- Social sharing
- Contact access
- Battery monitoring
- Network connectivity detection
- Text-to-speech
- Rating functionality

## Building the App

### Debug Build

To run the app in debug mode on a connected device or emulator:

```bash
flutter run
```

### Release Build (APK)

To create a release APK:

```bash
flutter build apk --release
```

The APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

### Release Build (App Bundle)

For Google Play Store submission:

```bash
flutter build appbundle --release
```

The bundle will be at: `build/app/outputs/bundle/release/app-release.aab`

### Code Signing

The app uses a signing configuration defined in `android/key.properties`. Ensure this file exists with:

```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=<path-to-your-keystore-file>
```

## Troubleshooting

### Common Issues

#### 1. "Flutter SDK not found"

Ensure your `PATH` includes the Flutter binary directory and restart your terminal.

```bash
which flutter
# Should output: /opt/homebrew/bin/flutter
```

#### 2. "Android SDK not found"

Verify `ANDROID_HOME` is set correctly:

```bash
echo $ANDROID_HOME
# Should output: /Users/your-username/Library/Android/sdk
```

#### 3. "sdkmanager: command not found"

Source your shell configuration file:

```bash
source ~/.zshrc
```

#### 4. Gradle Build Failures

Clean the build and try again:

```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

#### 5. "Licenses not accepted"

Run:

```bash
flutter doctor --android-licenses
```

### Getting Help

- **Flutter Documentation**: https://docs.flutter.dev/
- **Dart Documentation**: https://dart.dev/guides
- **Project Issues**: Contact your team lead or check internal documentation

## Development Guidelines

### For Developers Coming from Other Backgrounds

#### Java/C# Developers
- Dart uses similar OOP concepts with classes, interfaces, and inheritance
- Async/await works just like C#
- Strong typing with type inference
- Null safety similar to Kotlin's `?` operator

#### JavaScript Developers
- Arrow functions: `() => expression`
- Collection literals similar to JS
- Promise-like Future API
- Stream API similar to RxJS Observables

#### iOS/Swift Developers
- Widget tree similar to SwiftUI's View hierarchy
- Declarative UI paradigm
- Hot reload for rapid development
- Protocol-oriented programming via mixins

### Code Style

This project follows the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style). Use the analyzer:

```bash
flutter analyze
```

### Testing

This project follows a **pragmatic testing philosophy** with strict branch coverage requirements and automated test generation.

#### Quick Start

```bash
# Run all tests
make test

# Run tests with coverage report
make test-cov

# Check coverage for YOUR changes only (recommended before PR)
make test-my-changes

# Enforce coverage requirements (run before commit)
make coverage-check
```

#### Testing Philosophy

- **100% Branch Coverage**: NON-NEGOTIABLE for all new/changed code
- **Pragmatic Line Coverage**: 50-80% based on code criticality
  - Payment/Wallet modules: 80%
  - Services/Providers: 70%
  - Models/Pages: 60%
  - Widgets: 50%
- **Comprehensive tests over many small tests**
- **AAA pattern** (Arrange-Act-Assert)
- **Builder pattern** for test data

#### Automated Test Generation

Generate test skeletons automatically:

```bash
# Generate tests for a file
make generate-test FILE=lib/services/payment_service.dart

# This creates:
# - test/unit/services/payment_service_test.dart (test skeleton)
# - test/unit/services/payment_service_builder.dart (builder classes)
```

#### Coverage Reports

```bash
# Generate and open HTML coverage report
make coverage-report

# View coverage for changed files only
make test-my-changes
```
#
#### For More Details

See [COVERAGE_STRATEGY.md](COVERAGE_STRATEGY.md) for:
- Detailed testing patterns and examples
- Coverage requirements by module type
- AAA pattern examples
- Builder pattern usage
- FAQ and troubleshooting

## Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Provider State Management](https://pub.dev/packages/provider)
- [Firebase for Flutter](https://firebase.flutter.dev/)
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)

---

**Last Updated**: June 2026
**Maintained by**: Snabbit Mobile Team

import 'dart:math' as math;

import 'package:snabbit_runner/utils/common_methods.dart';

/// Enum representing the possible outcomes of a Shorebird update simulation
enum ShorebirdUpdateResult {
  silentPatch,
  crashPatch,
  invalidJson,
  ;

  bool get isCrash => this == ShorebirdUpdateResult.crashPatch;
}

/// Utility class for Shorebird update simulation
class ShorebirdUpdateUtil {
  /// Simulates Shorebird update logic
  ///
  /// [currentPatch] - Current patch number
  /// [latestPatch] - Latest available patch number
  /// [currentBuildCode] - Current build code from package info (e.g., "90", "93")
  /// [jsonConfig] - JSON configuration string
  ///
  /// Returns [ShorebirdUpdateResult] based on the simulation
  static ShorebirdUpdateResult needsCrash({
    required int currentPatch,
    required int latestPatch,
    required String currentBuildCode,
    required Map<String, dynamic>? jsonConfig,
  }) {
    try {
      // Validate JSON config exists
      if (jsonConfig == null) {
        return ShorebirdUpdateResult.invalidJson;
      }

      // Check if current build code exists in config
      if (!jsonConfig.containsKey(currentBuildCode)) {
        return ShorebirdUpdateResult.invalidJson;
      }

      final versionConfig = jsonConfig[currentBuildCode];

      // Validate version config structure
      if (versionConfig is! Map<String, dynamic>) {
        return ShorebirdUpdateResult.invalidJson;
      }

      late ShorebirdUpdateConfig shorebirdUpdateConfig;

      try {
        shorebirdUpdateConfig = ShorebirdUpdateConfig.fromJson(versionConfig);
      } catch (e) {
        return ShorebirdUpdateResult.invalidJson;
      }

      final minSupportedVersion = shorebirdUpdateConfig.minSupportedVersion;
      final unsupportedPatches = shorebirdUpdateConfig.unsupportedPatches;

      int minLatest = math.min(latestPatch, minSupportedVersion);

      if (unsupportedPatches.contains(minSupportedVersion)) {
        return ShorebirdUpdateResult.invalidJson;
      } else if (unsupportedPatches.contains(currentPatch)) {
        // Current patch is in unsupported list - crash
        return ShorebirdUpdateResult.crashPatch;
      } else if (currentPatch <= minLatest) {
        // Current patch is below minimum supported version - crash
        return ShorebirdUpdateResult.crashPatch;
      } else {
        // Patch is supported - silent update
        return ShorebirdUpdateResult.silentPatch;
      }
    } catch (e) {
      return ShorebirdUpdateResult.invalidJson;
    }
  }
}

class ShorebirdUpdateConfig {
  final int minSupportedVersion;
  final List<int> unsupportedPatches;

  ShorebirdUpdateConfig({
    required this.minSupportedVersion,
    required this.unsupportedPatches,
  });

  Map<String, dynamic> toJson() {
    return {
      'min_supported_version': minSupportedVersion,
      'unsupported_patches': unsupportedPatches,
    };
  }

  factory ShorebirdUpdateConfig.fromJson(Map<String, dynamic> json) {
    return ShorebirdUpdateConfig(
      minSupportedVersion: anyValueToInt(json['min_supported_version']) ?? -2,
      unsupportedPatches: json['unsupported_patches'] != null
          ? List<int>.from((json['unsupported_patches']).map((e) => anyValueToInt(e)))
          : [],
    );
  }
}

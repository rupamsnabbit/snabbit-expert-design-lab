import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/app_strings.dart';



/// Shorebird Code Push Service
///
/// Isolated service for managing Shorebird code push updates.
/// This service can be reused across different Flutter apps.
///
/// Features:
/// - Check for updates on specific tracks
/// - Download patches
/// - Get current patch number
/// - Generate full release version string
/// - Track applied patches to prevent infinite restart loops
class ShorebirdService {
  // Singleton instance
  static final ShorebirdService _instance = ShorebirdService._internal();
  static ShorebirdService get instance => _instance;
  factory ShorebirdService() => _instance;
  ShorebirdService._internal();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Get the current patch number
  ///
  /// Returns null if no patch is installed
  Future<int?> getCurrentPatchNumber() async {
    try {
      final patch = await _updater.readCurrentPatch();
      final patchNumber = patch?.number;
      return patchNumber;
    } catch (_) {
      return null;
    }
  }

  /// Get the next patch number
  ///
  /// Returns null if no patch is available
  Future<int?> getNextPatchNumber() async {
    try {
      final patch = await _updater.readNextPatch();
      final patchNumber = patch?.number;
      return patchNumber;
    } catch (_) {
      return null;
    }
  }

  /// Get the full release version string
  ///
  /// Format: "version+buildNumber-patchN" (e.g., "1.0.63+93-patch5")
  /// If no patch is installed, returns: "version+buildNumber"
  Future<String> getReleaseVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final baseVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

      final patchNumber = await getCurrentPatchNumber();

      if (patchNumber != null) {
        final fullVersion = '$baseVersion-patch$patchNumber';
        return fullVersion;
      } else {
        return baseVersion;
      }
    } catch (_) {
      return 'unknown';
    }
  }

  /// Check if an update is available for the specified track
  ///
  /// Returns true if update is available, false otherwise
  Future<bool> checkForUpdate({String track = 'stable'}) async {
    try {
      final updateTrack = track == 'stable' ? null : UpdateTrack(track);
      final status = await _updater.checkForUpdate(track: updateTrack);

      final isAvailable = status == UpdateStatus.outdated;

      return isAvailable;
    } catch (_) {
      return false;
    }
  }

  /// Download the patch for the specified track
  ///
  /// Returns true if download was successful, false otherwise
  Future<bool> downloadPatch({String track = 'stable'}) async {
    try {
      final updateTrack = track == 'stable' ? null : UpdateTrack(track);
      await _updater.update(track: updateTrack);

      final status = await _updater.checkForUpdate(track: updateTrack);

      final isRestartRequired = status == UpdateStatus.restartRequired;

      return isRestartRequired;
    } on UpdateException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get the active track
  ///
  /// Returns the track name stored in SharedPreferences, defaults to "stable"
  Future<String> getActiveTrack() async {
    try {
      final prefs = GlobalState().prefs;
      final track = prefs?.getString(AppStrings.shorebirdActiveTrack) ??
          UpdateTrack.stable.name;
      return track;
    } catch (_) {
      return 'stable';
    }
  }

  /// Set the active track
  ///
  /// Updates the track name in SharedPreferences
  Future<void> setActiveTrack(String track) async {
    try {
      final prefs = GlobalState().prefs;
      await prefs?.setString(AppStrings.shorebirdActiveTrack, track);
    } catch (_) {}
  }

  /// Restart the application
  ///
  /// This triggers app termination so that the new patch can be applied on next launch
  void restartApp() {
    exit(0);
  }
}

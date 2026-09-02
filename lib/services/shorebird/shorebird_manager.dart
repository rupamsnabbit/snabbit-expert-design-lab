import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/shorebird/shorebird_crash_check_util.dart';
import 'package:snabbit_runner/services/shorebird/shorebird_service.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

/// Shorebird Code Push Manager
///
/// Manages state for Shorebird code push updates and integrates with
/// Remote Config to control update rollout.
///
/// Features:
/// - Check for updates based on Remote Config
/// - Download patches and trigger app restart
/// - Prevent infinite restart loops
/// - Track update state and errors
class ShorebirdManager {
  static final ShorebirdManager _instance = ShorebirdManager._internal();
  static ShorebirdManager get instance => _instance;
  factory ShorebirdManager() => _instance;
  ShorebirdManager._internal();

  final ShorebirdService _shorebirdService = ShorebirdService.instance;
  final RemoteConfigService _remoteConfigService = RemoteConfigService.instance;

  StreamSubscription<bool>? _forcedReleaseSub;
  StreamSubscription<bool>? _rolloutFactorSub;

  bool _isChecking = false;
  bool _isDownloading = false;
  String? _error;
  int? _currentPatchNumber;
  String _currentTrack = UpdateTrack.stable.name;
  bool _updateAvailable = false;

  /// Whether the provider is currently checking for updates
  bool get isChecking => _isChecking;

  /// Whether the provider is currently downloading a patch
  bool get isDownloading => _isDownloading;

  /// Error message if an error occurred
  String? get error => _error;

  /// Current patch number installed
  int? get currentPatchNumber => _currentPatchNumber;

  /// Current active track
  String get currentTrack => _currentTrack;

  /// Whether an update is available
  bool get updateAvailable => _updateAvailable;

  /// Initialize the provider
  Future<void> initialize() async {
    try {
      _currentTrack = await _shorebirdService.getActiveTrack();
      _currentPatchNumber = await _shorebirdService.getCurrentPatchNumber();

      // Subscribe to Remote Config keys to trigger universal update checks
      _forcedReleaseSub = _remoteConfigService
          .onKeyUpdated(RemoteConfigKeys.forcedShorebirdReleaseConfig)
          .listen((_) {
        checkForUpdatesWithRemoteConfig(bypassDebounce: true);
      });
      _rolloutFactorSub = _remoteConfigService
          .onKeyUpdated(RemoteConfigKeys.shorebirdPatchRolloutFactor)
          .listen((_) {
        checkForUpdatesWithRemoteConfig(bypassDebounce: true);
      });

      refreshPatchInfo();
      checkForUpdatesWithRemoteConfig(bypassDebounce: false);
    } catch (e) {
      _error = 'Failed to initialize shorebird manager: $e';
    }
  }

  /// Get app version with Shorebird patch number
  ///
  /// Replaces the last number in version with the patch number.
  /// Example: "2.0.0" becomes "2.0.5" if patch 5 is installed
  /// Returns original version if no patch is installed
  Future<String> getAppVersion() async {
    bool showPatchCodeAsLegacy = _remoteConfigService.getBool(
      RemoteConfigKeys.showPatchCodeAsLegacy,
    );

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final patchNumber = await _shorebirdService.getCurrentPatchNumber();

      if (patchNumber == null) {
        return version;
      }

      // Split version by dots (e.g., "2.0.0" -> ["2", "0", "0"])
      final versionParts = version.split('.');

      if (versionParts.isEmpty) {
        return version;
      }

      // Replace the last part with patch number
      versionParts[versionParts.length - 1] = patchNumber.toString();

      // Join back (e.g., ["2", "0", "5"] -> "2.0.5")
      if (showPatchCodeAsLegacy == true) {
        final legacyVersion = versionParts.join('.');
        return legacyVersion;
      } else {
        final patchVersion = "$version($patchNumber)";
        return patchVersion;
      }
    } catch (e) {
      return 'unknown';
    }
  }

  /// Check if enough time has passed since last update check
  ///
  /// Debounce logic: minimum 5 minutes between checks
  Future<bool> shouldCheckForUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckTime = prefs.getInt(AppStrings.shorebirdLastCheckTime);

      if (lastCheckTime == null) {
        return true;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final timeSinceLastCheck = now - lastCheckTime;
      final int checkInterval = _remoteConfigService.getInt(
        RemoteConfigKeys.shorebirdPatchCheckInterval,
        defaultValue: 30,
      );
      final checkIntervalMs = checkInterval * 60 * 1000;

      final shouldCheck = timeSinceLastCheck >= checkIntervalMs;

      return shouldCheck;
    } catch (e) {
      return true; // Default to allowing check if error occurs
    }
  }

  /// Update the last check time
  Future<void> _updateLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(AppStrings.shorebirdLastCheckTime, now);
    } catch (e) {}
  }

  /// Check for updates using Remote Config
  ///
  /// This is the main method to call on app launch or home screen init.
  /// It checks Remote Config for the releases list and downloads patches if needed.
  Future<void> checkForUpdatesWithRemoteConfig({
    bool bypassDebounce = false,
  }) async {
    // Prevent multiple simultaneous checks
    if (_isChecking || _isDownloading) {
      return;
    }

    // Debounce: check only if enough time has passed (unless bypassed)
    if (!bypassDebounce && !await shouldCheckForUpdate()) {
      return;
    }

    _isChecking = true;
    _error = null;

    try {
      // Update last check time when not bypassing debounce
      if (!bypassDebounce) {
        await _updateLastCheckTime();
      }

      // Check if update is available
      final isUpdateAvailable = await _shorebirdService.checkForUpdate(
        track: _currentTrack,
      );

      _updateAvailable = isUpdateAvailable;

      if (!isUpdateAvailable) {
        _isChecking = false;
        return;
      }

      // Check rollout eligibility before downloading
      final shouldDownload = await _shouldDownloadBasedOnRollout();

      if (!shouldDownload) {
        _isChecking = false;

        return;
      }

      // Download and apply the patch
      await _downloadAndApplyPatch();
    } catch (e) {
      _error = 'Failed to check for updates: $e';
    } finally {
      _isChecking = false;
    }
  }

  /// Check if user should download based on rollout factor
  ///
  /// Uses customer ID mod rollout factor to determine eligibility
  Future<bool> _shouldDownloadBasedOnRollout() async {
    try {
      final currentContext = GlobalState().navigatorKey.currentContext;
      if (currentContext == null) {
        return false;
      }
      // Get user profile provider
      final userProfileProvider =
          Provider.of<UserProfileProvider>(currentContext, listen: false);
      final customerId = userProfileProvider.user?.id;

      if (customerId == null &&
          _remoteConfigService
                  .getBool(RemoteConfigKeys.shorebirdForLoggedOutUsers) ==
              true) {
        return true;
      }

      // Get rollout factor from Remote Config
      final rolloutFactor = _remoteConfigService.getInt(
        RemoteConfigKeys.shorebirdPatchRolloutFactor,
        defaultValue: 1, // Default to 100% rollout
      );

      // If customer ID is null, don't download
      if (customerId == null) {
        return false;
      }

      // Check if customer is in rollout percentage
      final remainder = customerId % rolloutFactor;
      final shouldDownload = remainder == 0;

      return shouldDownload;
    } catch (e) {
      // On error, default to not downloading
      return false;
    }
  }

  /// Download the patch and apply it by restarting the app
  ///
  /// This method will:
  /// 1. Download the patch
  /// 2. Get the new patch number
  /// 3. Check if it's already been applied
  /// 4. Build version string and check if it matches forced release
  /// 5. If forced: mark as applied and restart immediately
  /// 6. If not forced: mark as applied but don't restart (silent update)
  Future<void> _downloadAndApplyPatch() async {
    if (_isDownloading) {
      return;
    }

    _isDownloading = true;
    _error = null;

    try {
      // Download the patch
      final downloadSuccess = await _shorebirdService.downloadPatch(
        track: _currentTrack,
      );

      if (!downloadSuccess) {
        _error = 'Failed to download patch';
        _isDownloading = false;

        // Track download failure
        await _trackShorebirdEvent(
          event: TrackingEvents.shorebirdPatchDownload,
          eventData: {
            'status': 'failed',
            'error_message': 'Download failed',
            'track': _currentTrack,
          },
        );
        return;
      }

      // Track successful download
      await _trackShorebirdEvent(
        event: TrackingEvents.shorebirdPatchDownload,
        eventData: {
          'status': 'success',
          'track': _currentTrack,
        },
      );

      // Get the new patch number
      final newPatchNumber = await _shorebirdService.getNextPatchNumber();

      // Get forced release versions list from Remote Config
      final forcedReleasesList = _remoteConfigService.getJson(
        RemoteConfigKeys.forcedShorebirdReleaseConfig,
      );

      int? currentBuildCode = await getCurrentVersionCode();

      if (currentBuildCode == null) {
        _isDownloading = false;

        return;
      }

      // Check if this is a forced update (if new version is in forced list)
      final isForcedUpdate = ShorebirdUpdateUtil.needsCrash(
        currentPatch: currentPatchNumber ?? -1,
        latestPatch: newPatchNumber ?? -1,
        currentBuildCode: currentBuildCode.toString(),
        jsonConfig: forcedReleasesList,
      );

      if (isForcedUpdate.isCrash) {
        // Forced update: restart immediately

        // Track forced update before restart
        await _trackShorebirdEvent(
          event: TrackingEvents.shorebirdPatchApplied,
          eventData: {
            'applied_patch_number': newPatchNumber,
            'current_patch_number': currentPatchNumber,
            'track': _currentTrack,
            'update_type': 'forced',
            'app_restart_triggered': true,
          },
        );

        // Restart the app to apply the patch
        // Note: This will terminate the app, so code after this won't execute
        _shorebirdService.restartApp();
      } else {
        // Silent update: don't restart, will apply on next natural restart

        // Track silent update
        await _trackShorebirdEvent(
          event: TrackingEvents.shorebirdPatchApplied,
          eventData: {
            'applied_patch_number': newPatchNumber,
            'current_patch_number': currentPatchNumber,
            'track': _currentTrack,
            'update_type': 'silent',
            'app_restart_triggered': false,
          },
        );

        _currentPatchNumber = newPatchNumber;
        _isDownloading = false;
      }
    } catch (e) {
      _error = 'Failed to download and apply patch: $e';
      _isDownloading = false;

      // Track error
      await _trackShorebirdEvent(
        event: TrackingEvents.shorebirdPatchDownload,
        eventData: {
          'status': 'failed',
          'error_message': e.toString(),
          'track': _currentTrack,
        },
      );
    }
  }

  /// Set the active track
  ///
  /// This allows switching between different update tracks (e.g., stable, beta)
  Future<void> setActiveTrack(String track) async {
    try {
      await _shorebirdService.setActiveTrack(track);
      _currentTrack = track;
    } catch (_) {
      _error = 'Failed to set active track';
    }
  }

  /// Refresh current patch information
  Future<void> refreshPatchInfo() async {
    try {
      _currentPatchNumber = await _shorebirdService.getCurrentPatchNumber();
    } catch (e) {}
  }

  /// Get current version code from package info
  Future<int?> getCurrentVersionCode() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildNumber = int.tryParse(packageInfo.buildNumber);
      return buildNumber;
    } catch (e) {
      return null;
    }
  }

  /// Get next patch number from Shorebird service
  Future<int?> getNextPatchNumber() async {
    try {
      final nextPatch = await _shorebirdService.getNextPatchNumber();
      return nextPatch;
    } catch (e) {
      return null;
    }
  }

  /// Track Shorebird patch events to CleverTap
  Future<void> _trackShorebirdEvent({
    required String event,
    required Map<String, dynamic> eventData,
  }) async {
    try {
      await ClevertapSetup.logEvent(
        event,
        eventData,
      );
    } catch (e) {
      // Silently fail tracking to not affect core functionality
    }
  }

  void dispose() {
    try {
      _forcedReleaseSub?.cancel();
      _rolloutFactorSub?.cancel();
    } catch (e) {}
  }
}

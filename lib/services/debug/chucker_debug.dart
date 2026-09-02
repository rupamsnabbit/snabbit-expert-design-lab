import 'package:chucker_flutter/chucker_flutter.dart';
// DEBUG-ONLY reach into chucker_flutter internals: there is no public API to
// persist the notification settings, so we write through SharedPreferencesManager
// directly. Safe because every call site here is gated behind `kDebugMode`, so
// this file is dead code in release and tree-shaken out with the package.
// Coupled to chucker_flutter ^1.9.2.
// ignore: implementation_imports
import 'package:chucker_flutter/src/helpers/shared_preferences_manager.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/services/globals.dart';

/// Human labels for the Chucker notification-alignment presets offered in the
/// debug menu, keyed by the value stored in [GlobalState] / SharedPreferences.
const Map<String, String> chuckerAlignmentLabels = {
  'topCenter': 'Top center',
  'bottomCenter': 'Bottom center',
  'center': 'Center',
  'topRight': 'Top right',
  'bottomRight': 'Bottom right',
};

/// Maps a stored alignment preset key to a Flutter [Alignment].
/// Falls back to [Alignment.bottomCenter] (Chucker's own default).
Alignment chuckerAlignmentForKey(String key) {
  switch (key) {
    case 'topCenter':
      return Alignment.topCenter;
    case 'center':
      return Alignment.center;
    case 'topRight':
      return Alignment.topRight;
    case 'bottomRight':
      return Alignment.bottomRight;
    case 'bottomCenter':
    default:
      return Alignment.bottomCenter;
  }
}

/// Applies the persisted debug Chucker notification settings
/// ([GlobalState.debugChuckerShowNotification] and
/// [GlobalState.debugChuckerNotificationAlignment]) to `chucker_flutter`.
///
/// DEBUG-ONLY — call sites must be wrapped in `if (kDebugMode)`.
///
/// Sets the in-memory veto gate ([ChuckerFlutter.showNotification], which resets
/// to `true` on every app restart) and also persists the values into Chucker's
/// own settings store. The write-through matters because `showChuckerScreen()`
/// reloads settings from disk each time the inspector opens — without it, the
/// chosen alignment would revert to the default after opening the inspector once.
/// Existing Chucker settings (api thresholds, language, etc.) are preserved by
/// loading the current settings first and only overriding the two fields we own.
Future<void> applyChuckerDebugSettings() async {
  final show = GlobalState().debugChuckerShowNotification;
  final alignment =
      chuckerAlignmentForKey(GlobalState().debugChuckerNotificationAlignment);

  // Set the in-memory veto gate first, so the toggle still takes effect even
  // if persisting to disk below fails.
  ChuckerFlutter.showNotification = show;

  // Writing through to Chucker's own store can throw if the on-disk
  // `chucker_settings` blob is corrupt or from an incompatible version
  // (`Settings.fromJson` does unguarded casts). This runs awaited during app
  // startup, so swallow failures rather than block launch on a frozen splash.
  try {
    final manager = SharedPreferencesManager.getInstance();
    final current = await manager.getSettings();
    await manager.setSettings(
      current.copyWith(
        showNotification: show,
        notificationAlignment: alignment,
      ),
    );
  } catch (e) {
    debugPrint('applyChuckerDebugSettings: failed to persist settings: $e');
  }
}

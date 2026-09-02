// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safety_shield/safety_shield.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

import 'ui/shield_activation_bottom_sheet.dart';

const _activationSheetCountKey = 'shield_activation_sheet_shown_count';
const _accessibilityDialogCountKey =
    'shield_accessibility_dialog_shown_count';

/// Shows the activation bottom sheet at most [maxCount] times.
/// Returns true if the user tapped "Got it" or the sheet has already been
/// shown [maxCount] times (implied acknowledgement). Returns false if the
/// user dismissed the sheet without tapping "Got it".
Future<bool> maybeShowActivationSheet(
  BuildContext context, {
  required String source,
  required SharedPreferences? prefs,
  required void Function(String eventName, [Map<String, dynamic> extra])
      trackShieldEvent,
}) async {
  final maxCount = RemoteConfigService.instance.getInt(
    RemoteConfigKeys.shieldActivationSheetMaxShowCount,
    defaultValue: 10,
  );
  final prefsInstance = prefs ?? await SharedPreferences.getInstance();
  final count = prefsInstance.getInt(_activationSheetCountKey) ?? 0;
  if (count >= maxCount) return true;

  trackShieldEvent(TrackingEvents.expertShieldInfoBs, {'source': source});

  final result = await ShieldActivationBottomSheet.show(context);

  if (result == true) {
    trackShieldEvent(TrackingEvents.expertShieldInfoCta);
  } else {
    trackShieldEvent(TrackingEvents.expertShieldInfoDismiss);
  }

  await prefsInstance.setInt(_activationSheetCountKey, count + 1);
  return result == true;
}

/// Shows the accessibility permission dialog at most [maxCount] times.
///
/// Returns `true` if monitoring should continue (permission granted, dialog
/// skipped, or user dismissed). Returns `false` if user tapped "Open Settings"
/// (monitoring will resume after permission grant via onAppResumed).
Future<bool> maybeShowAccessibilityDialog(
  BuildContext context, {
  required SafetyShield shield,
  required SharedPreferences? prefs,
  required void Function(String message) log,
  required void Function(String eventName, [Map<String, dynamic> extra])
      trackShieldEvent,
  required void Function(bool value) setPendingManualStart,
}) async {
  final accessibilityStatus =
      await shield.checkPermission(SafetyPermission.accessibilityService);
  if (accessibilityStatus == SafetyPermissionStatus.granted) return true;

  final maxCount = RemoteConfigService.instance.getInt(
    RemoteConfigKeys.shieldAccessibilityDialogMaxShowCount,
    defaultValue: 3,
  );
  final prefsInstance = prefs ?? await SharedPreferences.getInstance();
  final count = prefsInstance.getInt(_accessibilityDialogCountKey) ?? 0;
  if (count >= maxCount) return true;

  log('accessibility service not enabled — requesting');
  trackShieldEvent(TrackingEvents.expertShieldError, {
    'error': 'accessibility_not_enabled',
    'trigger': ShieldTrigger.manual.value,
  });

  final lang = context.read<LanguageProvider>();
  final granted = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(lang.getMessage(
            'shield_accessibility_title', 'Accessibility Service')),
        content: Text(lang.getMessage('shield_accessibility_msg',
            'Accessibility service is not enabled. Please enable it to use the volume button SoS.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(lang.getMessage(
                  'shield_accessibility_cancel', 'Never Mind'))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(lang.getMessage(
                  'shield_accessibility_confirm', 'Open Settings'))),
        ],
      );
    },
  );

  await prefsInstance.setInt(_accessibilityDialogCountKey, count + 1);

  if (granted == true) {
    await shield.requestPermission(SafetyPermission.accessibilityService);
    setPendingManualStart(true);
    return false;
  }
  return true;
}

/// Whether the accessibility dialog is enabled for the current user's cluster.
bool isAccessibilityEnabledForCluster(UserProfileProvider userProfile) {
  final clusterIds = RemoteConfigService.instance
      .getList(RemoteConfigKeys.shieldAccessibilityEnabledClusterIds);
  if (clusterIds == null || clusterIds.isEmpty) return false;
  final userClusterId = userProfile.user?.clusterId;
  if (userClusterId == null) return false;
  return clusterIds.contains(userClusterId);
}

/// Polls [checkPermission] until the microphone permission is resolved.
/// Returns `true` if granted, `false` if denied or timed out.
Future<bool> pollForMicPermission(
  SafetyShield shield, {
  void Function(String)? log,
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 500),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await Future.delayed(interval);
    try {
      final status =
          await shield.checkPermission(SafetyPermission.microphone);
      if (status == SafetyPermissionStatus.granted) return true;
      // Any terminal non-granted status stops immediately — previously only
      // `denied` did, so iOS permanentlyDenied/restricted froze the UI for the
      // full timeout. Only `notDetermined` means the dialog may still be open.
      if (status == SafetyPermissionStatus.denied ||
          status == SafetyPermissionStatus.permanentlyDenied ||
          status == SafetyPermissionStatus.restricted) {
        return false;
      }
    } catch (e) {
      log?.call('_pollForMicPermission error: $e');
    }
  }
  return false; // timed out
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/info_action_bottom_sheet.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart'
    show RemoteImageHandler;

enum BatteryCheckResult { blocked, warning, ok }

const _sheetCooldownKey = 'shield_battery_sheet_last_shown';
const _defaultCooldownSecs = 2 * 60 * 60; // 2 hours

/// Checks battery level against Remote Config thresholds and optionally
/// shows an [InfoActionBottomSheet].
///
/// - Returns [BatteryCheckResult.blocked] if battery < block threshold (x%).
/// - Returns [BatteryCheckResult.warning] if battery < warn threshold (y%).
/// - Returns [BatteryCheckResult.ok] otherwise.
///
/// The bottom sheet is shown at most once every 2 hours (cooldown via
/// SharedPreferences). The [BatteryCheckResult] is always accurate regardless
/// of whether the sheet was displayed.
Future<BatteryCheckResult> checkShieldBattery(
  BuildContext context, {
  bool showSheet = true,
  Map<String, dynamic>? eventProps,
}) async {
  final blockThreshold = RemoteConfigService.instance.getInt(
    RemoteConfigKeys.shieldBatteryBlockThreshold,
    defaultValue: 15,
  );
  final warnThreshold = RemoteConfigService.instance.getInt(
    RemoteConfigKeys.shieldBatteryWarnThreshold,
    defaultValue: 20,
  );

  // Feature disabled if both thresholds are 0.
  if (blockThreshold <= 0 && warnThreshold <= 0) {
    return BatteryCheckResult.ok;
  }

  // Read battery level using existing utility.
  final batteryStr = await getBatteryLevel();
  if (batteryStr == null) {
    // Fail-open: can't read battery → don't block the user.
    return BatteryCheckResult.ok;
  }

  final battery = int.tryParse(batteryStr) ?? 100;

  // Determine result — block check first (stricter).
  final BatteryCheckResult result;
  if (blockThreshold > 0 && battery < blockThreshold) {
    result = BatteryCheckResult.blocked;
  } else if (warnThreshold > 0 && battery < warnThreshold) {
    result = BatteryCheckResult.warning;
  } else {
    return BatteryCheckResult.ok;
  }

  // Show sheet if allowed and cooldown has passed.
  if (!context.mounted) return result;
  final lang = context.read<LanguageProvider>();
  final labelString = result == BatteryCheckResult.blocked
      ? lang.getMessage(
          'snabbit_shield_battery_blocked_label', 'SNABBIT SHIELD LIMITED')
      : lang.getMessage('snabbit_shield_battery_warning_label', 'LOW BATTERY');

  if (showSheet && context.mounted) {
    final shouldShow =
        result == BatteryCheckResult.blocked ? true : await _cooldownPassed();
    if (shouldShow && context.mounted) {
      MixpanelSetup.logEvent(TrackingEvents.batteryPopupLoad, {
        ...?eventProps,
        'battery_percentage': battery,
        'result': result == BatteryCheckResult.blocked ? 'blocked' : 'warning',
      });
      await InfoActionBottomSheet.show(
        context,
        icon: RemoteImageHandler(
          imageUrl: "snabbit-shield/low_battery_icon.png".cdn,
          width: 100.w,
          height: 100.h,
          fit: BoxFit.contain,
        ),
        label: labelString,
        title: lang.getMessage(
            'snabbit_shield_battery_title', 'Battery is running low'),
        subtitle: lang.getMessage('snabbit_shield_battery_subtitle',
            'Please charge your phone to keep Snabbit Kavach active.'),
        buttonText: lang.getMessage('snabbit_shield_battery_btn', 'I will do'),
      );
      MixpanelSetup.logEvent(TrackingEvents.batteryPopupDismiss, {
        ...?eventProps,
        'battery_percentage': battery,
        'result': result == BatteryCheckResult.blocked ? 'blocked' : 'warning',
      });
      // Only save cooldown for warnings; blocked always shows regardless
      // so it shouldn't prevent a subsequent warning from appearing.
      if (result == BatteryCheckResult.warning) {
        await _saveCooldownTimestamp();
      }
    }
  }

  return result;
}

Future<bool> _cooldownPassed() async {
  final cooldownSecs = RemoteConfigService.instance.getInt(
    RemoteConfigKeys.shieldBatterySheetCooldownSecs,
    defaultValue: _defaultCooldownSecs,
  );
  final prefs = await SharedPreferences.getInstance();
  final lastShown = prefs.getInt(_sheetCooldownKey) ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  return (now - lastShown) >= cooldownSecs * 1000;
}

Future<void> _saveCooldownTimestamp() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_sheetCooldownKey, DateTime.now().millisecondsSinceEpoch);
}

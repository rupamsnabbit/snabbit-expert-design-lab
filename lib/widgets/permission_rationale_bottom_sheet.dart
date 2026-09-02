import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

/// Analytics outcome reported when the user returns from app settings. Mirrors
/// the values the camera-permission flow has always emitted so existing
/// dashboards keep working when callers wire these through.
class PermissionSettingsOutcome {
  PermissionSettingsOutcome._();

  static const String granted = 'granted';
  static const String askEveryTime = 'ask_every_time';
  static const String stillDenied = 'still_denied';
}

/// Generic "permission required" bottom sheet shown when a device permission is
/// denied during a bifrost flow. Guides the user to app settings and
/// automatically re-checks the permission when the app resumes.
///
/// Pops with `true` if the user resolved the permission (granted, or reset to
/// "ask every time" so the native prompt can be shown again), or `false` if the
/// user dismisses the sheet / it times out.
///
/// This widget is permission-agnostic: callers supply the [permission], copy,
/// timeout and analytics hooks. See [CameraPermissionBottomSheet] and
/// [ContactsPermissionBottomSheet] for the configured wrappers.
class PermissionRationaleBottomSheet extends StatefulWidget {
  const PermissionRationaleBottomSheet({
    super.key,
    required this.permission,
    required this.status,
    required this.icon,
    required this.titleKey,
    required this.titleFallback,
    required this.descriptionKey,
    required this.descriptionFallback,
    required this.timeoutSecs,
    required this.logPrefix,
    this.dismissNotifier,
    this.externalDismissReason = 'external_dismiss',
    this.onSettingsResult,
    this.onTimeout,
  });

  /// The permission this sheet is guiding the user to grant.
  final Permission permission;

  /// The [PermissionStatus] that triggered this sheet (e.g. `denied`,
  /// `permanentlyDenied`, `restricted`).
  final PermissionStatus status;

  /// Leading icon shown at the top of the sheet.
  final IconData icon;

  /// LanguageProvider key + fallback for the title.
  final String titleKey;
  final String titleFallback;

  /// LanguageProvider key + fallback for the description.
  final String descriptionKey;
  final String descriptionFallback;

  /// How long (seconds) to wait after the user taps "Open Settings" before
  /// auto-dismissing, so the awaiting RPC unblocks if the user never returns.
  /// Callers resolve this from Remote Config.
  final int timeoutSecs;

  /// Prefix for `MonitoringServiceHelper` log keys, e.g.
  /// `camera_permission_sheet` → `camera_permission_sheet_shown`.
  final String logPrefix;

  /// When set, the owning flow flips this notifier to `true` to dismiss the
  /// sheet externally (e.g. the web aborts the RPC). The sheet then pops
  /// `false` promptly instead of waiting for the settings timeout.
  final ValueNotifier<bool>? dismissNotifier;

  /// `reason` value logged when the sheet is dismissed via [dismissNotifier].
  /// Lets callers preserve their existing analytics taxonomy.
  final String externalDismissReason;

  /// Invoked once, after the user returns from app settings, with the analytics
  /// outcome (see [PermissionSettingsOutcome]) and the re-checked status name.
  final void Function(String outcome, String statusName)? onSettingsResult;

  /// Invoked once when the settings timeout fires.
  final VoidCallback? onTimeout;

  @override
  State<PermissionRationaleBottomSheet> createState() =>
      _PermissionRationaleBottomSheetState();
}

class _PermissionRationaleBottomSheetState
    extends State<PermissionRationaleBottomSheet>
    with WidgetsBindingObserver {
  bool _waitingForResume = false;

  /// Guards against a double-pop. The settings timeout (a [Timer]) and the
  /// resume re-check can both reach a `pop` in the same frame — and
  /// `Timer.cancel()` does not un-queue an already-fired callback, so the
  /// `mounted` check alone doesn't prevent it. The first resolve wins; the
  /// rest are no-ops, so we never tear down the route beneath the sheet.
  bool _resolved = false;

  Timer? _settingsTimer;

  Duration get _settingsTimeout => Duration(seconds: widget.timeoutSecs);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.dismissNotifier?.addListener(_onExternalDismiss);
    MonitoringServiceHelper.logInfo('${widget.logPrefix}_shown', {
      'initialStatus': widget.status.name,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  void dispose() {
    widget.dismissNotifier?.removeListener(_onExternalDismiss);
    _settingsTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Externally-initiated cancellation — close the sheet.
  void _onExternalDismiss() {
    if (widget.dismissNotifier?.value == true) {
      MonitoringServiceHelper.logInfo('${widget.logPrefix}_dismissed', {
        'reason': widget.externalDismissReason,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _resolveWith(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForResume) {
      _waitingForResume = false;
      _settingsTimer?.cancel();
      _settingsTimer = null;
      _checkPermissionAndMaybePop();
    }
  }

  /// Maps the [PermissionStatus] (re-checked after the user returns from app
  /// settings) to its analytics outcome.
  ///
  /// `isDenied` here means the OS reset `permanentlyDenied → denied` because
  /// the user chose "Ask Every Time", so the native prompt can be shown again.
  static String _settingsOutcomeForStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionSettingsOutcome.granted;
    }
    if (status.isDenied) return PermissionSettingsOutcome.askEveryTime;
    return PermissionSettingsOutcome
        .stillDenied; // permanentlyDenied / restricted
  }

  Future<void> _checkPermissionAndMaybePop() async {
    final status = await widget.permission.status;
    if (!mounted) return;

    final outcome = _settingsOutcomeForStatus(status);
    widget.onSettingsResult?.call(outcome, status.name);

    // 'still_denied' (permanentlyDenied / restricted) keeps the sheet open so
    // the user can tap "Open Settings" again; granted / ask_every_time pop it.
    if (outcome != PermissionSettingsOutcome.stillDenied) {
      _resolveWith(true);
    }
  }

  /// Pops the sheet exactly once. Subsequent calls (racing dismiss paths:
  /// timeout vs. resume vs. back-press vs. external dismiss) are ignored.
  void _resolveWith(bool granted) {
    if (_resolved || !mounted) return;
    _resolved = true;
    Navigator.of(context).pop(granted);
  }

  Future<void> _openSettings() async {
    _waitingForResume = true;
    _settingsTimer?.cancel();
    _settingsTimer = Timer(_settingsTimeout, _onSettingsTimeout);
    MonitoringServiceHelper.logInfo('${widget.logPrefix}_open_settings', {
      'timestamp': DateTime.now().toIso8601String(),
    });
    final opened = await openAppSettings();
    // If the settings activity couldn't be launched (no settings app, OEM
    // quirk, restricted profile), the app never backgrounds, so `resumed`
    // never fires — don't leave the user stuck on the sheet until the
    // timeout. Cancel and dismiss now (handler returns PERMISSION_DENIED).
    if (!opened && mounted) {
      _settingsTimer?.cancel();
      _settingsTimer = null;
      _waitingForResume = false;
      MonitoringServiceHelper.logWarning(
        '${widget.logPrefix}_open_settings_failed',
        {'timestamp': DateTime.now().toIso8601String()},
      );
      _resolveWith(false);
    }
  }

  /// Called when the user has been in settings longer than
  /// [_settingsTimeout]. Dismisses the sheet so the RPC pipeline unblocks
  /// (handler returns `PERMISSION_DENIED` to the web).
  void _onSettingsTimeout() {
    if (!mounted) return;
    _waitingForResume = false;
    MonitoringServiceHelper.logWarning('${widget.logPrefix}_timeout', {
      'timestamp': DateTime.now().toIso8601String(),
    });
    widget.onTimeout?.call();
    _resolveWith(false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Hardware back pressed — treat as cancellation.
          MonitoringServiceHelper.logInfo('${widget.logPrefix}_dismissed', {
            'reason': 'back_press',
            'timestamp': DateTime.now().toIso8601String(),
          });
          _resolveWith(false);
        }
      },
      child: CommonBottomSheetSetup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16.h),

            // Icon
            Icon(widget.icon, size: 48.r, color: AppColors.n60),
            SizedBox(height: 16.h),

            // Title
            Text(
              lang.getMessage(widget.titleKey, widget.titleFallback),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),

            // Description
            Text(
              lang.getMessage(
                widget.descriptionKey,
                widget.descriptionFallback,
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.n60),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),

            // Open Settings button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openSettings,
                child: Text(lang.getMessage('open_settings', 'Open Settings')),
              ),
            ),
            SizedBox(height: 8.h),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  MonitoringServiceHelper.logInfo(
                    '${widget.logPrefix}_dismissed',
                    {
                      'reason': 'cancel_button',
                      'timestamp': DateTime.now().toIso8601String(),
                    },
                  );
                  _resolveWith(false);
                },
                child: Text(lang.getMessage('cancel', 'Cancel')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

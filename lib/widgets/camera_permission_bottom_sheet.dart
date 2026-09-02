import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/permission_rationale_bottom_sheet.dart';

/// Bottom sheet shown when camera permission is denied during the bifrost
/// `captureImage` flow. Thin wrapper over [PermissionRationaleBottomSheet]
/// configured for [Permission.camera] — guides the user to app settings and
/// automatically re-checks permission when the app resumes.
///
/// Pops with `true` if the user resolved permission (detected on resume),
/// or `false` if the user dismisses the sheet.
class CameraPermissionBottomSheet extends StatelessWidget {
  const CameraPermissionBottomSheet({
    super.key,
    required this.status,
    this.dismissNotifier,
  });

  /// Fallback timeout when Remote Config hasn't set a value or returns 0.
  static const int _defaultTimeoutSecs = 120;

  /// The [PermissionStatus] that triggered this sheet (e.g. `denied`,
  /// `permanentlyDenied`, `restricted`).
  final PermissionStatus status;

  /// When the web sends `cancelCapture` while this sheet is open, the handler
  /// flips this notifier to `true`; the sheet then dismisses itself (pops
  /// `false`) so the capture RPC unblocks promptly instead of waiting for the
  /// settings timeout.
  final ValueNotifier<bool>? dismissNotifier;

  @override
  Widget build(BuildContext context) {
    return PermissionRationaleBottomSheet(
      permission: Permission.camera,
      status: status,
      icon: Icons.camera_alt_outlined,
      titleKey: 'camera_permission_required_title',
      titleFallback: 'Camera Permission Required',
      descriptionKey: 'camera_permission_required_desc',
      descriptionFallback:
          'Camera access is needed to capture your selfie. '
          'Please enable it in your device settings.',
      // Driven by Remote Config so ops can tune the duration without a release.
      timeoutSecs: RemoteConfigService.instance.getNonZeroInt(
        RemoteConfigKeys.capturePermissionSheetTimeoutSecs,
        defaultValue: _defaultTimeoutSecs,
      ),
      logPrefix: 'camera_permission_sheet',
      dismissNotifier: dismissNotifier,
      externalDismissReason: 'cancel_capture',
      onSettingsResult: (outcome, statusName) => MixpanelSetup.logEvent(
        TrackingEvents.capturePermissionSheetResult,
        {'outcome': outcome, 'status': statusName},
      ),
      onTimeout: () => MixpanelSetup.logEvent(
        TrackingEvents.capturePermissionSheetTimeout,
        {},
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/permission_rationale_bottom_sheet.dart';

/// Bottom sheet shown when contacts permission is denied during the bifrost
/// `getContacts` flow. Thin wrapper over [PermissionRationaleBottomSheet]
/// configured for [Permission.contacts] — guides the user to app settings and
/// automatically re-checks permission when the app resumes.
///
/// Pops with `true` if the user resolved permission (detected on resume),
/// or `false` if the user dismisses the sheet.
class ContactsPermissionBottomSheet extends StatelessWidget {
  const ContactsPermissionBottomSheet({super.key, required this.status});

  /// Fallback timeout when Remote Config hasn't set a value or returns 0.
  static const int _defaultTimeoutSecs = 120;

  /// The [PermissionStatus] that triggered this sheet (e.g. `denied`,
  /// `permanentlyDenied`, `restricted`).
  final PermissionStatus status;

  @override
  Widget build(BuildContext context) {
    return PermissionRationaleBottomSheet(
      permission: Permission.contacts,
      status: status,
      icon: Icons.contacts_outlined,
      titleKey: 'contacts_permission_required_title',
      titleFallback: 'Contacts Permission Required',
      descriptionKey: 'contacts_permission_required_desc',
      descriptionFallback:
          'Contacts access is needed to show your phonebook '
          'so you can refer friends. Please enable it in your device settings.',
      // Driven by Remote Config so ops can tune the duration without a release.
      // Shares the capture sheet's knob — same backstop, no need for two.
      timeoutSecs: RemoteConfigService.instance.getNonZeroInt(
        RemoteConfigKeys.capturePermissionSheetTimeoutSecs,
        defaultValue: _defaultTimeoutSecs,
      ),
      logPrefix: 'contacts_permission_sheet',
      onSettingsResult: (outcome, statusName) => MixpanelSetup.logEvent(
        TrackingEvents.contactsPermissionSheetResult,
        {'outcome': outcome, 'status': statusName},
      ),
      onTimeout: () => MixpanelSetup.logEvent(
        TrackingEvents.contactsPermissionSheetTimeout,
        {},
      ),
    );
  }
}

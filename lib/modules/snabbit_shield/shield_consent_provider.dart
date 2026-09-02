import 'dart:async';

import 'package:flutter/material.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'shield_http.dart';
import 'package:snabbit_runner/modules/snabbit_shield/ui/shield_consent_bottom_sheet.dart';

class ShieldConsentProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _consentSheetDismissed = false;
  bool _isSheetVisible = false;
  Completer<bool>? _sheetCompleter;

  bool get isLoading => _isLoading;

  List<String> get blockedWidgets =>
      GlobalState().appConfig?.blockedShieldConsentWidgets ??
      [
        'RUNNER_JOB_POST_ACCEPT',
        'RUNNER_JOB_CHECK_IN',
        'RUNNER_NEW_JOB',
        'RUNNER_SUSPENDED',
      ];

  /// Consent is required unless it was explicitly granted (`true`). A `null`
  /// value means the backend has no recorded decision yet — we must still
  /// prompt before monitoring, since recording audio without explicit consent
  /// is not acceptable. (Previously `null` skipped the prompt while SoS was
  /// still blocked on `consentGiven == true` — an inconsistent, privacy-wrong
  /// state; both paths now require consent.)
  bool needsConsent(UserProfile? user) => user?.consentGiven != true;

  bool canShowOnWidget(String? widgetName) =>
      widgetName == null || !blockedWidgets.contains(widgetName);

  /// Opportunistic consent check for partner_home on-load.
  /// Respects [_consentSheetDismissed] — won't re-show after dismiss.
  Future<bool> showConsentIfNeeded(BuildContext context, UserProfile? user,
      {Map<String, dynamic>? eventProps}) async {
    if (user == null || !user.safetyShieldEnabled) return false;
    if (!needsConsent(user)) return true;

    if (_isSheetVisible || _consentSheetDismissed) return false;

    return _showSheet(context, user,
        source: 'home_page', eventProps: eventProps);
  }

  /// Consent gate for shield start (auto-start / Start Monitoring).
  /// Ignores [_consentSheetDismissed] — always shows if consent is missing.
  /// If the consent sheet is already visible (from opportunistic check),
  /// waits for its result instead of returning false.
  Future<bool> ensureConsent(BuildContext context, UserProfile? user,
      {Map<String, dynamic>? eventProps}) async {
    // Profile not yet loaded — do not show the consent sheet during the load
    // window. startShield will be re-triggered after the profile resolves.
    if (user == null) return false;
    if (!needsConsent(user)) return true;

    // If the sheet is already visible (e.g. from showConsentIfNeeded),
    // wait for it to complete and use that result.
    if (_isSheetVisible && _sheetCompleter != null) {
      return _sheetCompleter!.future;
    }

    return _showSheet(context, user,
        source: 'shield_start', eventProps: eventProps);
  }

  Future<bool> _showSheet(
    BuildContext context,
    UserProfile? user, {
    required String source,
    Map<String, dynamic>? eventProps,
  }) async {
    _isSheetVisible = true;
    _sheetCompleter = Completer<bool>();

    MixpanelSetup.logEvent(TrackingEvents.expertShieldConsentBs, {
      ...?eventProps,
      'runner_id': user?.id,
      'consent_given': user?.consentGiven == true ? 'Y' : 'N',
      'source': source,
    });

    try {
      final result = await ShieldConsentBottomSheet.show(context,
          consentProvider: this, eventProps: eventProps);
      if (!result) {
        _consentSheetDismissed = true;
      }

      _sheetCompleter!.complete(result);
      return result;
    } catch (e) {
      MixpanelSetup.logEvent(TrackingEvents.expertShieldConsentError, {
        ...?eventProps,
        'runner_id': user?.id,
        'error': e.toString(),
      });
      _sheetCompleter!.complete(false);
      return false;
    } finally {
      _isSheetVisible = false;
      _sheetCompleter = null;
    }
  }

  /// Called from the bottom sheet's Activate button.
  /// Returns true on API success, false on failure.
  Future<bool> activateConsent(UserProfileProvider userProfileProvider) async {
    _isLoading = true;
    notifyListeners();

    final response = await ShieldHttp.activateSnabbitShield();
    _isLoading = false;
    notifyListeners();

    if (response != null && response.statusCode == 200) {
      userProfileProvider.consentGiven = true;
      MixpanelSetup.logEvent(TrackingEvents.expertShieldConsentGiven, {
        'runner_id': userProfileProvider.user?.id,
      });
      return true;
    }

    await MonitoringServiceHelper.logError(
      'Snabbit Shield consent activation failed',
      {
        'api': 'activate_consent',
        'status_code': response?.statusCode,
        'runner_id': userProfileProvider.user?.id,
        'reason': response == null ? 'null_response' : 'non_200',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    return false;
  }
}

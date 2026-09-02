import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/loan_provider.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/widgets/loan/loan_bottom_sheets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/loan/utils/loan_tracking.dart';

class LoanService {
  static Future<void> handleLoanAction(
    BuildContext context,
    LoanProvider loanProvider,
    String source,
  ) async {
    final languageProvider = context.read<LanguageProvider>();

    showLoanUnifiedSheet(
      context,
      languageProvider,
      loanProvider,
      source,
    );

    // If not already loading and no data, start fetching
    if (!loanProvider.isLoading && loanProvider.loanDetails == null) {
      await loanProvider.fetchLoanDetails();
    }
  }

  static Future<void> openVendorUrl(
    BuildContext context,
    String url,
    String source,
  ) async {
    bool success = false;
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        MonitoringServiceHelper.logError(
          'Could not launch loan URL: $url',
          {},
        );
        if (context.mounted) {
          showSnackbar(context, 'Could not open loan details');
        }
      } else {
        success = true;
      }
    } catch (e) {
      MonitoringServiceHelper.logError(
        'Error opening loan vendor URL: $e',
        {},
      );
      if (context.mounted) {
        showSnackbar(context, 'Invalid loan URL');
      }
    } finally {
      LoanTracking.trackLoanExternalUrlLaunch(
        url: url,
        source: source,
        success: success,
      );
    }
  }
}

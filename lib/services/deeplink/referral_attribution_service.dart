import 'package:dio/dio.dart';
import 'package:snabbit_runner/referrals/services/referral_http.dart';
import 'package:snabbit_runner/services/deeplink/referral_attribution_store.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

typedef ValidateLinkSender = Future<Response?> Function({
  required String referrerId,
  String? campaignId,
});

class ReferralAttributionService {
  ReferralAttributionService._();

  static const int _maxRetryAttempts = 5;

  static Future<void> validateCapturedLink({
    ValidateLinkSender sender = ReferralHttp.validateLink,
  }) async {
    try {
      final attribution = await ReferralAttributionStore.read();
      if (attribution == null) return;

      if (GlobalState().payoutsUrl.isEmpty) {
        MonitoringServiceHelper.logWarning(
          'referral_validate_link_skipped_no_base_url',
          {'env': GlobalState().currentEnv.name},
        );
        return;
      }

      final response = await sender(
        referrerId: attribution.referrerId,
        campaignId: attribution.campaignId,
      );
      final status = response?.statusCode ?? 0;
      final isNetworkFailure = status == 0;
      final isServerError = status >= 500;
      final isRetryableClientError = status == 408 || status == 429;
      final shouldRetry =
          isNetworkFailure || isServerError || isRetryableClientError;
      if (!shouldRetry) {
        await ReferralAttributionStore.clear();
        return;
      }

      if (attribution.attemptCount + 1 >= _maxRetryAttempts) {
        MonitoringServiceHelper.logWarning(
          'referral_validate_link_gave_up',
          {
            'attempts': attribution.attemptCount + 1,
            'last_status': status,
          },
        );
        await ReferralAttributionStore.clear();
      } else {
        await ReferralAttributionStore.incrementAttempt();
      }
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'referral_validate_link_orchestration_failed',
        {'error': e.toString()},
      );
    }
  }
}

import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class ReferralHttp {
  static Future<int?> referralBannerAmount() async {
    try {
      final response = await HttpService().get(
        GlobalState().bffServerPath('v1/referrals/campaign/banner'),
        headers: {},
        suppressUnauthorizedHandler: true,
      );
      if (response.statusCode != 200) return null;
      final data = response.data?['data'];
      if (data is! Map) return null;
      return anyValueToInt(data['amount']);
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'referralBannerAmount failed',
      );
      return null;
    }
  }

  static Future<Response?> validateLink({
    required String referrerId,
    String? campaignId,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().payoutsServerPath("api/v1/referrals/link/validate"),
        headers: {},
        data: {
          "referrer_id": anyValueToInt(referrerId),
          if (campaignId != null) "campaign_id": anyValueToInt(campaignId),
        },
        suppressUnauthorizedHandler: true,
      );
      return response;
    } catch (e) {
      MonitoringServiceHelper.logWarning(
        'referral_validate_link_failed',
        {'error': e.toString()},
      );
      return null;
    }
  }

  static Future<Response?> getWalletData({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
          "api/v1/runner_referral_widget/me/wallet",
        ),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getRefereeDetails({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
          "api/v1/runner_referral_widget/me/referrer",
        ),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> withdrawWallet({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
          "api/v1/runner_referral_wallet/me/withdraw",
        ),
        headers: headers ?? {},
        data: data ?? {},
      );
      // if (response.statusCode == 200) {
      return response;
      // } else {
      //   return null;
      // }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> referrerCardShown({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().put(
        GlobalState().serverPath(
          "api/v1/runner_referrals/referrer_card/shown",
        ),
        headers: headers ?? {},
        data: data ?? {},
      );
      // if (response.statusCode == 200) {
      return response;
      // } else {
      //   return null;
      // }
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> remind({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath(
          "api/v1/runner_referrals/remind",
        ),
        headers: headers ?? {},
        data: data ?? {},
      );
      // if (response.statusCode == 200) {
      return response;
      // } else {
      //   return null;
      // }
    } catch (e) {
      return null;
    }
  }
}

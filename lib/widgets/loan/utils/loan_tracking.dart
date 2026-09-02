import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';

class LoanTracking {
  LoanTracking._();

  static const String _eventLoanBannerImpression = 'loan_banner_impression';
  static const String _eventLoanBannerClick = 'loan_banner_click';
  static const String _eventLoanExternalUrlLaunched =
      'loan_external_url_launched';
  static const String _eventLoanBottomSheetImpression =
      'loan_bottom_sheet_impression';
  static const String _eventLoanBottomSheetAction = 'loan_bottom_sheet_action';

  static Map<String, dynamic> _getCommonAttributes() {
    try {
      final context = GlobalState().navigatorKey.currentContext;
      if (context != null) {
        final userProfile = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        );
        final user = userProfile.user;

        return {
          'runner_id': user?.id,
        };
      }
    } catch (e) {
      // If we can't get the context or provider, return empty map
    }
    return {};
  }

  static Future<void> trackLoanBannerImpression({
    required String source,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'source': source,
    };

    await ClevertapSetup.logEvent(_eventLoanBannerImpression, properties);
  }

  static Future<void> trackLoanBannerClick({
    required String source,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'source': source,
    };

    await ClevertapSetup.logEvent(_eventLoanBannerClick, properties);
  }

  static Future<void> trackLoanExternalUrlLaunch({
    required String url,
    required String source,
    bool success = true,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'url': url,
      'source': source,
      'success': success,
    };
    await ClevertapSetup.logEvent(_eventLoanExternalUrlLaunched, properties);
  }

  static Future<void> trackLoanBottomSheetImpression({
    required String state, // 'early_payout', 'loan_processed'
    required String source,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'state': state,
      'source': source,
    };
    await ClevertapSetup.logEvent(_eventLoanBottomSheetImpression, properties);
  }

  static Future<void> trackLoanBottomSheetAction({
    required String action, // 'understood', 'view_details'
    required String state,
    required String source,
  }) async {
    final properties = {
      ..._getCommonAttributes(),
      'action': action,
      'state': state,
      'source': source,
    };
    await ClevertapSetup.logEvent(_eventLoanBottomSheetAction, properties);
  }
}

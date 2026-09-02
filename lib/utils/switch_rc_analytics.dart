import 'package:snabbit_runner/providers/user_profile.dart';

/// Common cohort / location / rate-card-id properties for switch-RC
/// events (drawer banner + provisional bottom sheet). Sends raw signals
/// only — analyst derives `cohort` enum (higher_earnings / lower_earnings
/// / newapril_onboarded) from the raw fields server-side.
///
/// `runner_id` is intentionally not included — Mixpanel.identify and
/// CleverTap.setCustomer attach the user identity to every event at
/// login (see lib/pages/login/select_language_v2.dart).
Map<String, dynamic> switchRcCommonProps(UserProfile? user) {
  return {
    'rc_id': user?.rateCard,
    'rate_card_version': user?.rateCardVersion.name,
    'rate_card_optin_month': user?.rateCardOptinMonth,
    'has_lower_earnings_in_new_rate_card':
        user?.hasLowerEarningsInNewRateCard,
    'city': user?.clusterId,
    'region_id': user?.regionId,
    'banner_variant': user?.languagePreference,
  };
}

import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class ReferralAttribution {
  const ReferralAttribution({
    required this.referrerId,
    this.campaignId,
    this.attemptCount = 0,
  });

  final String referrerId;
  final String? campaignId;
  final int attemptCount;

  static ReferralAttribution? fromOneLinkParams(Map<String, dynamic> raw) {
    final referrerId = raw['deep_link_sub1'];
    if (referrerId is! String || referrerId.trim().isEmpty) return null;
    final referrer = referrerId.trim();
    if (anyValueToInt(referrer) == null) return null;

    final campaignId = raw['deep_link_sub2'];
    final campaign = campaignId is String && campaignId.trim().isNotEmpty
        ? campaignId.trim()
        : null;
    return ReferralAttribution(
      referrerId: referrer,
      campaignId: anyValueToInt(campaign) != null ? campaign : null,
    );
  }
}

class ReferralAttributionStore {
  ReferralAttributionStore._();

  static const String _referrerIdKey = 'referral_attribution_referrer_id';
  static const String _campaignIdKey = 'referral_attribution_campaign_id';
  static const String _attemptCountKey = 'referral_attribution_attempt_count';

  static Future<void> save({
    required String referrerId,
    String? campaignId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_referrerIdKey, referrerId);
    if (campaignId != null && campaignId.isNotEmpty) {
      await prefs.setString(_campaignIdKey, campaignId);
    } else {
      await prefs.remove(_campaignIdKey);
    }
    await prefs.remove(_attemptCountKey);
  }

  static Future<ReferralAttribution?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final referrerId = prefs.getString(_referrerIdKey);
    if (referrerId == null || referrerId.isEmpty) return null;
    return ReferralAttribution(
      referrerId: referrerId,
      campaignId: prefs.getString(_campaignIdKey),
      attemptCount: prefs.getInt(_attemptCountKey) ?? 0,
    );
  }

  static Future<void> incrementAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_attemptCountKey) ?? 0;
    await prefs.setInt(_attemptCountKey, current + 1);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_referrerIdKey);
    await prefs.remove(_campaignIdKey);
    await prefs.remove(_attemptCountKey);
  }
}

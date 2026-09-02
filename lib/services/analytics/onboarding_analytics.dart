import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/analytics/kmp_analytics_channel.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Onboarding-funnel analytics helper.
///
/// Holds only TRULY cross-event super properties (device + selected_language).
/// Flow-specific context (phone_masked, otp_provider, resend_count,
/// sms_permission_granted) is attached per-event by the call sites.
///
/// User-identity props (runner_id, returning_expert, expert_status_at_login)
/// go to the Mixpanel user profile via [identifyOnLogin]; dashboard queries
/// join via runner_id.
///
/// Time deltas are computed downstream from Mixpanel/CleverTap event
/// timestamps — no client-side session timing.
///
/// Events go to Mixpanel (via [MixpanelSetup], which forwards to the KMP
/// analytics module) and CleverTap. The KMP-side route table decides which
/// providers (Mixpanel / AppsFlyer) receive each event.
class OnboardingAnalytics {
  OnboardingAnalytics._();

  static final Map<String, dynamic> _superProps = {};
  static int _resendCount = 0;

  static int get resendCount => _resendCount;

  @visibleForTesting
  static Map<String, dynamic> get superPropsForTest =>
      Map.unmodifiable(_superProps);

  @visibleForTesting
  static void resetForTest() {
    _superProps.clear();
    _resendCount = 0;
  }

  static void registerSuperProperties(Map<String, dynamic> props) {
    _superProps.addAll(props);
    // Forward to the shared Dart-side store on KmpAnalyticsChannel so the
    // props fan to every provider the route table picks (Mixpanel + CleverTap),
    // not just Mixpanel as before.
    KmpAnalyticsChannel.instance.registerSuperProperties(props);
  }

  /// Drop all super-properties across every store — this helper's map, the
  /// [KmpAnalyticsChannel] Dart store, and the KMP tracker's store. Call on
  /// forced logout (403) so a previous user's runner_id/cluster_id/region_id
  /// can't ride onto the logged-out window's events or the next login.
  static void clearSuperProperties() {
    _superProps.clear();
    KmpAnalyticsChannel.instance.clearSuperProperties();
  }

  /// Masks a phone number to first-5 + Xs (e.g. 8606612345 → 86066XXXXX).
  /// Pure function — does not touch super props.
  static String maskPhone(String phone) {
    if (phone.length < 5) return phone;
    return '${phone.substring(0, 5)}${'X' * (phone.length - 5)}';
  }

  static void incrementResendCount() {
    _resendCount += 1;
  }

  static void resetResendCount() {
    _resendCount = 0;
  }

  /// Full post-login setup: identifies the runner on Mixpanel + AppsFlyer
  /// (via KMP channel), sets the Mixpanel user profile, and registers
  /// cross-event super props.
  ///
  /// `identify` is awaited before `setUserProfile` because `people.set()`
  /// targets the current `distinct_id` — firing setUserProfile before
  /// identify has landed would attach runner properties to the anonymous
  /// id instead of the runner id (PR #361 alkalox-snabbit review). The
  /// remaining calls stay fire-and-forget for parallelism.
  ///
  /// Caller's `unawaited(...)` keeps the login flow non-blocking; the
  /// inner Future resolves after one MethodChannel round-trip
  /// (~3–5 ms typical) once the Mixpanel identify has landed, instead
  /// of immediately. `.catchError` on each call routes failures to
  /// `MonitoringServiceHelper` without bubbling unhandled futures.
  static Future<void> identifyOnLogin(UserProfile profile) async {
    final id = profile.id.toString();

    // identify fans to all KMP providers (Mixpanel + AppsFlyer
    // setCustomerUserId). Awaited before setUserProfile so that, over the
    // FIFO MethodChannel, Mixpanel's identify lands before people.set —
    // otherwise the runner profile attaches to the anonymous distinct_id.
    await MixpanelSetup.identify(id).catchError(
      (e) => MonitoringServiceHelper.logError(
        'mp_identify_failed',
        {'error': e.toString()},
      ),
    );

    // Safe now — Mixpanel's distinct_id is the runner id.
    MixpanelSetup.setUserProfile({
      '\$phone': profile.phoneNumber,
      '\$name': profile.name,
      'runner_id': profile.id,
      'cluster_id': profile.clusterId,
      'region_id': profile.regionId,
      'runner_status': profile.runnerStatus?.name,
      'language_preference': profile.languagePreference,
      'joining_date': profile.joiningDate?.toIso8601String(),
      'gender': profile.gender?.value?.name,
      'safety_shield_enabled': profile.safetyShieldEnabled,
      'service_id': profile.service?.id,
      'returning_expert':
          ((profile.registrationStep?.currentValue ?? 0) > 1) ? 1 : 0,
      'expert_status_at_login': profile.registrationStep?.rawStep,
    }).catchError(
      (e) => MonitoringServiceHelper.logError(
        'mp_set_user_profile_failed',
        {'error': e.toString()},
      ),
    );

    // Use the helper (not MixpanelSetup directly) so these also land in
    // _superProps — the only store fanned out to CleverTap via logEvent.
    // A direct MixpanelSetup call reaches Mixpanel events but leaves
    // CleverTap funnel events unsegmentable by cluster/region.
    registerSuperProperties({
      'runner_id': profile.id,
      'cluster_id': profile.clusterId,
      'region_id': profile.regionId,
    });
  }

  /// Fires to CleverTap and to Mixpanel (via [MixpanelSetup], which
  /// forwards to the KMP analytics module; the route table also delivers
  /// to AppsFlyer for routed events). Super props are merged in; call-site
  /// props win on conflict.
  static void logEvent(String name, Map<String, dynamic> props) {
    final merged = <String, dynamic>{
      ..._superProps,
      ...props,
    };
    // Single forward — the central catalog fans this to Mixpanel + CleverTap.
    MixpanelSetup.logEvent(name, merged);
  }
}

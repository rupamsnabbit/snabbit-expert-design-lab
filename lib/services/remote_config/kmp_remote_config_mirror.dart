import 'dart:async';

import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/job_overlay_channel.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_api.g.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/set_rate_card_opted_in_handler.dart'
    show kAlreadyDidV2OptInPrefsKey;

/// Mirrors the Remote Config flags the KMP module needs across the Pigeon
/// [RemoteConfigHostApi] bridge — both **bool** flags and **string** (JSON)
/// configs.
///
/// Firebase Remote Config lives on the Flutter side; the KMP (`:shared`) module
/// has no RC path of its own, so we push a snapshot after RC is available and
/// again whenever it changes. KMP reads each flag with a matching **safe
/// default** ([_boolSnapshot] / [_stringSnapshot] document them), so a
/// failed/absent push just means KMP falls back to those defaults — never a
/// wrong gate.
///
/// Call [push] after RC init, on live config updates, and after the post-login
/// targeting refetch (see `main.dart` / `UserProfileProvider`).
class KmpRemoteConfigMirror {
  KmpRemoteConfigMirror._();

  static final RemoteConfigHostApi _api = RemoteConfigHostApi();

  /// Bool flags KMP screens gate on. Each default MUST match the KMP-side
  /// `getBool(key, default)` call for the same key:
  ///  - `expert_show_earnings` → `true`  (Profile: Monthly earnings tile)
  ///  - `expert_is_referrals_v2_enabled` → `false` (Profile: Refer & earn → webview)
  ///  - `expert_enable_vishwaas_rate_card_banner` → `false` (Profile: Vishwaas banner)
  ///  - `already_did_v2_opt_in` → `false` (Vishwaas gate ①; a SharedPreferences
  ///    flag, not an RC value — set by the rate-card opt-in webview handler)
  ///  - `expert_enable_auto_ot` → `false` (KMP Auto-OT kill-switch; the KMP
  ///    `AutoOtCoordinator` gates all offers on it, mirroring this Flutter gate)
  ///  - `expert_show_new_job_overlay_on_other_apps` → `false` (native new-job overlay
  ///    triggers gate the draw-over-other-apps overlay on this via the KMP gateway)
  ///  - `expert_show_red_card_pill` → `false` (KMP home top-nav red card pill)
  ///  - `expert_enable_saathi_ticketing` → `false` (KMP home Saathi pill →
  ///    `v1/support` webview instead of the IVR call; absent push leaves
  ///    the shipped call behaviour)
  ///  - `expert_is_notifications_tab_enabled` → `false` (KMP bottom-nav
  ///    Notifications tab; staged rollout — absent/failed push leaves it hidden)
  static Map<String, bool> _boolSnapshot() {
    final rc = RemoteConfigService.instance;
    return {
      RemoteConfigKeys.showEarnings:
          rc.getBool(RemoteConfigKeys.showEarnings, defaultValue: true),
      RemoteConfigKeys.isReferralsV2Enabled: rc.getBool(
        RemoteConfigKeys.isReferralsV2Enabled,
        defaultValue: false,
      ),
      RemoteConfigKeys.enableVishwaasRateCardBanner: rc.getBool(
        RemoteConfigKeys.enableVishwaasRateCardBanner,
        defaultValue: false,
      ),
      RemoteConfigKeys.enableAutoOt:
          rc.getBool(RemoteConfigKeys.enableAutoOt, defaultValue: false),
      RemoteConfigKeys.showNewJobOverlayOnOtherApps: rc.getBool(
        RemoteConfigKeys.showNewJobOverlayOnOtherApps,
        defaultValue: false,
      ),
      RemoteConfigKeys.showRedCardPill: rc.getBool(
        RemoteConfigKeys.showRedCardPill,
        defaultValue: false,
      ),
      RemoteConfigKeys.enableSaathiTicketing: rc.getBool(
        RemoteConfigKeys.enableSaathiTicketing,
        defaultValue: false,
      ),
      RemoteConfigKeys.isNotificationsTabEnabled: rc.getBool(
        RemoteConfigKeys.isNotificationsTabEnabled,
        defaultValue: false,
      ),
      kAlreadyDidV2OptInPrefsKey:
          GlobalState().prefs?.getBool(kAlreadyDidV2OptInPrefsKey) ?? false,
    };
  }

  /// String configs KMP reads. Each default MUST match the KMP-side
  /// `getString(key, default)` call for the same key:
  ///  - `expert_vishwaas_banner` → "" (unified Vishwaas config; empty ⇒ no banner)
  ///  - `expert_vishwaas_drawer_banner` → "" (legacy flat fallback)
  ///  - `expert_saathi_helpline_number` → "02244582683" (KMP home Saathi pill dialer)
  ///  - `expert_sos_contact_number` → "+919004108043" (KMP Help sheet's helpline
  ///    fallback when `runners/me/helpline` returns nothing)
  ///  - `expert_max_blocked_customers` → "" (Block list "n/max" header cap; KMP
  ///    parses to int, empty/non-numeric ⇒ unknown ⇒ header shows just "n")
  ///  - `expert_job_end_campaign_min_remaining_mins` → "5" (job-end campaign shows
  ///    only when more than this many minutes of job time remain at checkout)
  ///  - `expert_job_audio_half_time_excluded_durations` → "[]" (ECPO-982: job
  ///    durations, minutes, for which the half-time voice cue is suppressed)
  ///  - `expert_job_audio_ten_min_excluded_durations` → "[]" (same, for the
  ///    T-minus-10 cue). The auto-checkout list is NOT mirrored — that cue is
  ///    Dart-played, so `loopSound` reads it directly via
  ///    `getString(..., '[]')` + a tolerant bracket/CSV parse (not `getList`).
  ///  - `expert_job_location_timeout_ms` → "500" (max ms KMP job actions wait for a
  ///    location fix before sending the action without one)
  static Map<String, String> _stringSnapshot() {
    final rc = RemoteConfigService.instance;
    return {
      RemoteConfigKeys.expertVishwaasBanner:
          rc.getString(RemoteConfigKeys.expertVishwaasBanner),
      RemoteConfigKeys.expertVishwaasDrawerBanner:
          rc.getString(RemoteConfigKeys.expertVishwaasDrawerBanner),
      RemoteConfigKeys.expertSaathiHelplineNumber: rc.getString(
        RemoteConfigKeys.expertSaathiHelplineNumber,
        defaultValue: '02244582683',
      ),
      RemoteConfigKeys.expertSosContactNumber: rc.getString(
        RemoteConfigKeys.expertSosContactNumber,
        defaultValue: '+919004108043',
      ),
      // Block list "n/max" cap; empty default ⇒ KMP treats the cap as unknown (hides "/max").
      RemoteConfigKeys.expertMaxBlockedCustomers:
          rc.getString(RemoteConfigKeys.expertMaxBlockedCustomers),
      // Job-end campaign threshold (minutes remaining); KMP job screen reads with the same "5" default.
      RemoteConfigKeys.jobEndCampaignMinRemainingMins: rc.getString(
        RemoteConfigKeys.jobEndCampaignMinRemainingMins,
        defaultValue: '5',
      ),
      // Job-in-progress audio cue exclusion lists (ECPO-982); KMP parses these JSON arrays
      // tolerantly and reads with the same "[]" default. Auto-checkout's list stays Dart-only.
      RemoteConfigKeys.jobAudioHalfTimeExcludedDurations: rc.getString(
        RemoteConfigKeys.jobAudioHalfTimeExcludedDurations,
        defaultValue: '[]',
      ),
      RemoteConfigKeys.jobAudioTenMinExcludedDurations: rc.getString(
        RemoteConfigKeys.jobAudioTenMinExcludedDurations,
        defaultValue: '[]',
      ),
      // Job-action location fetch timeout (ms); KMP CoreJobLocationProvider reads with the same "500" default.
      RemoteConfigKeys.jobLocationTimeoutMs: rc.getString(
        RemoteConfigKeys.jobLocationTimeoutMs,
        defaultValue: '500',
      ),
    };
  }

  /// Push the current snapshots to KMP. Fire-and-forget: a bridge failure (e.g.
  /// KMP disabled for this process) is logged, never propagated to the caller.
  static Future<void> push() async {
    try {
      // `expert_ameyo_support` feeds a DIFFERENT KMP sink than the Pigeon RC
      // bridge below: the delayed check-in disposition VM reads it live from
      // `RunnerSessionStore.ameyoSupport`, which is fed only by the job-launcher
      // channel (JobScreenLauncherPlugin.setAmeyoSupport). Mirror it here — the
      // same freshness points as every other KMP RC flag — so callback mode is
      // actually reachable (default false = degrade-safe dial mode, matching
      // both RunnerSessionStore's default and `delayed_checkin_http.dart`).
      // Fired BEFORE the Pigeon awaits so a bridge failure can't skip it (the
      // two sinks are independent channels).
      unawaited(
        JobOverlayChannel.setAmeyoSupport(
          RemoteConfigService.instance.getBool(
            RemoteConfigKeys.ameyoSupport,
            defaultValue: false,
          ),
        ),
      );
      await _api.setBoolFlags(_boolSnapshot());
      await _api.setStringFlags(_stringSnapshot());
    } catch (e) {
      MonitoringServiceHelper.logError(
        'kmp_remote_config_push_failed',
        {'error': e.toString()},
      );
    }
  }
}

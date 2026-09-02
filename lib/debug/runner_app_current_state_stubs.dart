import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/app_strings.dart';

/// Named presets for [GlobalState.debugStubRunnerAppCurrentStateBody].
/// Shapes follow `GET …/runners/me/app/current_state` (widget envelope + optional totals).
enum RunnerAppCurrentStateStub {
  attendanceTomorrow,
  attendanceToday,
  attendanceAbsent,

  /// [RUNNER_ATTENDANCE_ABSENT]: provisional marked absent (`attendance_type` ABSENT),
  /// `change_atn` so runner can open sheet and mark present.
  attendanceAbsentProvisionalToday,

  /// [RUNNER_ATTENDANCE_ABSENT]: no-show with `no_show_red_card_count` for card cluster UI.
  attendanceAbsentNoShow,
  attendanceConfirmed,
  newJobAssigned,

  /// [RUNNER_NEW_JOB] with `is_last_hour_job` — deny sheet: Logout + Accept.
  newJobAssignedLastHour,
  seeYouTomorrow,
  suspended,
  jobCancelled,
  waitHotspot,
  selfieCheck,
  loginLocation,
  loginHotspot,

  /// [RUNNER_LOGIN_HOTSPOT] with `pre_action_nudges` EARLY_LOGIN risk nudge (red card pill + CTA).
  stubTestEarlyLogin,
  jobPostAccept,
  jobCheckIn,
  jobInProgress,
  logout,
  lunch,
  lunchRequest,
  lunchCooldown,
  postCheckout,
  preMarkArrival,
  errorWidget,
}

extension RunnerAppCurrentStateStubX on RunnerAppCurrentStateStub {
  /// Short label for debug UI.
  String get debugTitle {
    switch (this) {
      case RunnerAppCurrentStateStub.attendanceTomorrow:
        return 'RUNNER_ATTENDANCE_TOMORROW';
      case RunnerAppCurrentStateStub.attendanceToday:
        return 'RUNNER_ATTENDANCE_TODAY';
      case RunnerAppCurrentStateStub.attendanceAbsent:
        return 'RUNNER_ATTENDANCE_ABSENT';
      case RunnerAppCurrentStateStub.attendanceAbsentProvisionalToday:
        return 'RUNNER_ATTENDANCE_ABSENT (today, change → present)';
      case RunnerAppCurrentStateStub.attendanceAbsentNoShow:
        return 'RUNNER_ATTENDANCE_ABSENT (NO_SHOW + red cards)';
      case RunnerAppCurrentStateStub.attendanceConfirmed:
        return 'RUNNER_ATTENDANCE_CONFIRMED';
      case RunnerAppCurrentStateStub.newJobAssigned:
        return 'RUNNER_NEW_JOB (job assigned)';
      case RunnerAppCurrentStateStub.newJobAssignedLastHour:
        return 'RUNNER_NEW_JOB (last hour)';
      case RunnerAppCurrentStateStub.seeYouTomorrow:
        return 'RUNNER_SEE_YOU_TOMORROW';
      case RunnerAppCurrentStateStub.suspended:
        return 'RUNNER_SUSPENDED';
      case RunnerAppCurrentStateStub.jobCancelled:
        return 'RUNNER_JOB_CANCELLED';
      case RunnerAppCurrentStateStub.waitHotspot:
        return 'RUNNER_WAIT_HOTSPOT';
      case RunnerAppCurrentStateStub.selfieCheck:
        return 'SELFIE_CHECK';
      case RunnerAppCurrentStateStub.loginLocation:
        return 'RUNNER_LOGIN_LOCATION';
      case RunnerAppCurrentStateStub.loginHotspot:
        return 'RUNNER_LOGIN_HOTSPOT';
      case RunnerAppCurrentStateStub.stubTestEarlyLogin:
        return 'RUNNER_LOGIN_HOTSPOT (EARLY_LOGIN nudge + pill)';
      case RunnerAppCurrentStateStub.jobPostAccept:
        return 'RUNNER_JOB_POST_ACCEPT (accepted, pre check-in)';
      case RunnerAppCurrentStateStub.jobCheckIn:
        return 'RUNNER_JOB_CHECK_IN (checked in)';
      case RunnerAppCurrentStateStub.jobInProgress:
        return 'RUNNER_JOB_IN_PROGRESS';
      case RunnerAppCurrentStateStub.logout:
        return 'RUNNER_LOGOUT';
      case RunnerAppCurrentStateStub.lunch:
        return 'LUNCH';
      case RunnerAppCurrentStateStub.lunchRequest:
        return 'LUNCH_REQUEST';
      case RunnerAppCurrentStateStub.lunchCooldown:
        return 'LUNCH_COOLDOWN';
      case RunnerAppCurrentStateStub.postCheckout:
        return 'RUNNER_POST_CHECKOUT (rate customer)';
      case RunnerAppCurrentStateStub.preMarkArrival:
        return 'PRE_MARK_ARRIVAL';
      case RunnerAppCurrentStateStub.errorWidget:
        return 'ERROR_WIDGET';
    }
  }
}

/// Sample JSON bodies for local / test use. Not exhaustive vs production BE.
class RunnerAppCurrentStateStubs {
  RunnerAppCurrentStateStubs._();

  static Map<String, dynamic> _envelope(
    String widgetName,
    Map<String, dynamic> widgetData,
  ) {
    return <String, dynamic>{
      'widget_name': widgetName,
      'widget_data': widgetData,
      'gold_coins_total': 42,
      'red_cards_total': 0,
    };
  }

  static Map<String, dynamic> _jobFlowWidgetData({
    required int jobId,
    bool enableArrival = true,
    String payment = 'Pending',
  }) {
    return <String, dynamic>{
      'start_time': '4:20 pm',
      'end_time': '11:00 am',
      'customer_ph_no': '+919876543210',
      'duration': 30,
      'payment': payment,
      'Payment': payment,
      'customer_name': 'Stub Customer',
      'lat': 19.0760,
      'lng': 72.8777,
      'address': 'Stub Tower A',
      'geo_address': 'Stub City, Maharashtra, India',
      'mark_arrival_radius': 500,
      'enable_arrival': enableArrival,
      'job_id': jobId,
      'show_timer': true,
    };
  }

  /// Full response body for [stub].
  static Map<String, dynamic> body(RunnerAppCurrentStateStub stub) {
    switch (stub) {
      case RunnerAppCurrentStateStub.attendanceTomorrow:
        return _envelope('RUNNER_ATTENDANCE_TOMORROW', {
          'date': 'Monday 24th June',
          'shift_time': '10:00 am - 06:00 pm',
          'type': 'TOMORROW',
          'earning_loss_amount': 50,
        });
      case RunnerAppCurrentStateStub.attendanceToday:
        return _envelope('RUNNER_ATTENDANCE_TODAY', {
          'date': 'Sunday 23rd June',
          'start_date_ist': '2024-06-23',
          'shift_time': '10:00 am - 06:00 pm',
          'type': 'TODAY',
        });
      case RunnerAppCurrentStateStub.attendanceAbsent:
        return _envelope('RUNNER_ATTENDANCE_ABSENT', {
          'date': 'Monday 24th June',
          'start_date_ist': '2024-06-24',
          'type': 'TOMORROW',
          'change_atn': true,
          'attendance_type': 'ABSENT',
          'shift_time': '10:00 am - 06:00 pm',
          'lost_ming_amount': 50,
        });
      case RunnerAppCurrentStateStub.attendanceAbsentProvisionalToday:
        return _envelope('RUNNER_ATTENDANCE_ABSENT', {
          'date': 'Tuesday 25th June',
          'start_date_ist': '2024-06-25',
          'type': 'TODAY',
          'change_atn': true,
          'attendance_type': 'ABSENT',
          'shift_time': '10:00 am - 06:00 pm',
          'lost_ming_amount': 50,
        });
      case RunnerAppCurrentStateStub.attendanceAbsentNoShow:
        return _envelope('RUNNER_ATTENDANCE_ABSENT', {
          'date': 'Saturday 8th June',
          'start_date_ist': '2024-06-08',
          'type': 'TODAY',
          'attendance_type': 'NO_SHOW',
          'shift_time': '8:00 am - 2:00 pm',
          'no_show_red_card_count': 5,
          'fp_penalty': 50,
        });
      case RunnerAppCurrentStateStub.attendanceConfirmed:
        return <String, dynamic>{
          ..._envelope('RUNNER_ATTENDANCE_CONFIRMED', {
            'date': 'Monday 24th June',
            'start_date_ist': '2024-06-24',
            'type': 'TOMORROW',
            'change_atn': true,
            'shift_time': '10:00 am - 06:00 pm',
            'show_earnings_cta': true,
          }),
          'sheet_warnings': [
            {
              'lifecycle_action_type': 'PROVISIONAL_MARK_ABSENT',
              'cta_overrides': [
                {
                  'cta_id': 'mark_absent',
                  'red_cards': 3,
                },
              ],
            },
          ],
        };
      case RunnerAppCurrentStateStub.newJobAssigned:
        final notified = DateTime.now()
            .toUtc()
            .subtract(const Duration(seconds: 10))
            .toIso8601String();
        return _envelope('RUNNER_NEW_JOB', {
          'start_time': '20:34 pm',
          'lat': 19.0760,
          'lng': 72.8777,
          'address': 'Stub address line',
          'geo_address': 'Stub geo, India',
          'runner_job_id': 9012,
          'notified_at': notified,
          'timer_duration': 120,
          'is_deniable': false,
          'loss_amount': 50,
          'payout_info': {
            'total_earning': 350,
            'breakdown': [
              {
                'title': {'key': 'work', 'default_text': 'Work'},
                'pill_text': '1 hr',
                'amount': 250,
              },
              {
                'title': {
                  'key': 'long_distance_label',
                  'default_text': 'Long Distance'
                },
                'pill_text': '1.2 kms',
                'amount': 20,
              },
              {
                "title": {
                  "key": "monsoon_bonus",
                  "default_text": "Monsoon Bonus"
                },
                "pill_text": "30 min",
                "icon_url":
                    "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/payouts/rate-card-v2/rain.png",
                "amount": 35.0,
                "subtitle": {
                  "key": "monsoon_bonus_subtitle",
                  "default_text": "₹10 + ₹25 Extra"
                }
              },
              {
                'title': {'key': 'ot_label', 'default_text': 'OT'},
                'pill_text': '15 min',
                'amount': 50,
              },
            ],
            'check_in_amount': 30,
            'check_in_time': '2030-01-15T16:30:00.000+05:30',
          },
          'pre_action_nudges': [
            {
              'lifecycle_action_type': 'ACCEPT_JOB_PENALTY',
              'nudge_kind': 'risk',
              'icon_url':
                  'https://assets-expert.snabbit.com/payouts/nudges/red_card_straight.png',
              'label': {
                'key': 'legacy_literal',
                'params': {
                  'text':
                      'Stub: accepting late may add a red card — check timer',
                },
              },
              'red_cards': 1,
            },
          ],
        });
      case RunnerAppCurrentStateStub.newJobAssignedLastHour:
        final notifiedLh = DateTime.now()
            .toUtc()
            .subtract(const Duration(seconds: 10))
            .toIso8601String();
        return _envelope('RUNNER_NEW_JOB', {
          'start_time': '04:30 pm',
          'lat': 19.0760,
          'lng': 72.8777,
          'address': 'Stub address line',
          'geo_address': 'Stub geo, India',
          'notified_at': notifiedLh,
          'timer_duration': 120,
          'is_deniable': true,
          'is_last_hour_job': true,
          'runner_job_id': 9010,
          'accept_rate': 500,
          'deny_rate': 50,
          'loss_amount': 50,
          'payout_info': {
            'total_earning': 350,
            'breakdown': [
              {
                'title': {'key': 'work', 'default_text': 'Work'},
                'pill_text': '1 hr',
                'amount': 250,
              },
              {
                'title': {
                  'key': 'long_distance_label',
                  'default_text': 'Long Distance'
                },
                'pill_text': '1.2 kms',
                'amount': 20,
              },
              {
                'title': {
                  'key': 'summer_bonus',
                  'default_text': 'Summer Bonus ☀️'
                },
                'pill_text': '1 hr + 15 min',
                'amount': 30,
              },
              {
                'title': {'key': 'ot_label', 'default_text': 'OT'},
                'pill_text': '15 min',
                'amount': 50,
              },
            ],
            'check_in_amount': 30,
            'check_in_time': '2030-01-15T16:30:00.000+05:30',
          },
          'pre_action_nudges': [
            {
              'lifecycle_action_type': 'ACCEPT_JOB_PENALTY',
              'nudge_kind': 'risk',
              'icon_url':
                  'https://assets-expert.snabbit.com/payouts/nudges/red_card_straight.png',
              'label': {
                'key': 'legacy_literal',
                'params': {
                  'text':
                      'Stub (last hour): accepting late may add a red card — check timer',
                },
              },
              'red_cards': 1,
            },
          ],
        });
      case RunnerAppCurrentStateStub.seeYouTomorrow:
        return _envelope('RUNNER_SEE_YOU_TOMORROW', {});
      case RunnerAppCurrentStateStub.suspended:
        return _envelope('RUNNER_SUSPENDED', {});
      case RunnerAppCurrentStateStub.jobCancelled:
        return _envelope('RUNNER_JOB_CANCELLED', {
          'job_id': 9001,
        });
      case RunnerAppCurrentStateStub.waitHotspot:
        return _envelope('RUNNER_WAIT_HOTSPOT', {
          'lat': 19.0760,
          'lng': 72.8777,
        });
      case RunnerAppCurrentStateStub.selfieCheck:
        return _envelope('SELFIE_CHECK', {});
      case RunnerAppCurrentStateStub.loginLocation:
        return _envelope('RUNNER_LOGIN_LOCATION', {
          'lat': 19.0760,
          'lng': 72.8777,
          'start_date_ist': '2024-04-24',
        });
      case RunnerAppCurrentStateStub.loginHotspot:
        return _envelope('RUNNER_LOGIN_HOTSPOT', {
          'hotspot_lat': 19.0760,
          'hotspot_lng': 72.8777,
          'auto_login_enabled': false,
          'start_date_ist': '2024-04-24',
        });
      case RunnerAppCurrentStateStub.stubTestEarlyLogin:
        final earlyLoginExpires = DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 30))
            .toIso8601String();
        final earlyLoginNudge = <String, dynamic>{
          'lifecycle_action_type': 'EARLY_LOGIN',
          'nudge_kind': 'reward',
          'step': 'T_TO_T_PLUS_30',
          'icon_url':
              'https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/payouts/rate-card-v2/risk_icon.png',
          'label': {
            'key': 'nudge_early_login_avoid_no_show',
            'params': {
              'time': '04:00 pm',
              'red_cards': 1,
            },
            'default_text': 'Login by 04:00 pm to avoid No Show',
          },
          'gold_coins': null,
          'red_cards': 1,
          'expires_at': earlyLoginExpires,
          'warnings': null,
          'cta_overrides': [
            {
              'cta_id': 'login',
              'label': {
                'key': 'login',
                'params': null,
                'default_text': 'Login',
              },
              'gold_coins': null,
              'red_cards': 1,
            },
          ],
        };
        return <String, dynamic>{
          ..._envelope('RUNNER_LOGIN_HOTSPOT', {
            'shift_time': '03:30 pm - 10:00 pm',
            'login_start_time': '03:30 pm',
            'start_time': '04:00 pm',
            'lat': 12.93367,
            'lng': 77.62038,
            'enable_login': true,
            'login_radius': 350,
            'address': 'devi park',
            'geo_address': 'devi park',
            'date': 'Friday 24th April',
            'start_date_ist': '2024-04-24',
            'show_early_login_bonus': false,
            'login_by_time': null,
            'early_login_bonus_amount': null,
            'early_login_banner_url': null,
            'fp_penalty_amount': null,
            'change_atn': false,
            'pending_pan': true,
            'pending_bank': true,
            'login_pending_warning': false,
            'login_pending_lost_ming': false,
            'login_by_time_utc': null,
            'auto_login_enabled': false,
            'auto_login_seconds': null,
            'auto_login_acknowledged_at': null,
            'pre_action_nudges': [earlyLoginNudge],
            'gold_coins_total': 0,
            'red_cards_total': 0,
            'sos_visibility': {
              'visible': true,
              'reason': 'PRE_LOGIN_WINDOW',
              'window_end_ts': '2026-04-24T16:30:00+05:30',
            },
          }),
          'gold_coins_total': null,
          'red_cards_total': null,
          'pre_action_nudges': [earlyLoginNudge],
          'sheet_warnings': [
            {
              'lifecycle_action_type': 'EMERGENCY_LOGOUT',
              'nudge_kind': 'risk',
              'step': null,
              'icon_url': null,
              'label': null,
              'gold_coins': null,
              'red_cards': 3,
              'expires_at': null,
              'warnings': null,
              'cta_overrides': [
                {
                  'cta_id': 'go_back',
                  'label': {
                    'key': 'go_back',
                    'params': null,
                    'default_text': 'Go Back',
                  },
                  'gold_coins': null,
                  'red_cards': null,
                },
                {
                  'cta_id': 'logout',
                  'label': {
                    'key': 'logout',
                    'params': null,
                    'default_text': 'Logout',
                  },
                  'gold_coins': null,
                  'red_cards': 3,
                },
              ],
            },
          ],
        };
      case RunnerAppCurrentStateStub.jobPostAccept:
        return _envelope('RUNNER_JOB_POST_ACCEPT', {
          ..._jobFlowWidgetData(jobId: 9002),
          'payout_info': {
            'total_earning': 280,
            'breakdown': [
              {
                'title': {'key': 'work', 'default_text': 'Work'},
                'pill_text': '1 hr',
                'amount': 250,
              },
            ],
            'check_in_amount': 30,
            'check_in_time': '2030-01-15T16:20:00.000+05:30',
          },
        });
      case RunnerAppCurrentStateStub.jobCheckIn:
        return _envelope('RUNNER_JOB_CHECK_IN', {
          ..._jobFlowWidgetData(jobId: 9003),
          // Mirror the mark-arrival-disabled flow: check-in served pre-arrival
          // (show_timer already true via _jobFlowWidgetData), with the No-OTP
          // secondary enabled and no auto-arrival.
          'allow_check_in_without_otp': true,
          'auto_arrival': false,
          'payout_info': {
            'total_earning': 280,
            'breakdown': [
              {
                'title': {'key': 'work', 'default_text': 'Work'},
                'pill_text': '1 hr',
                'amount': 250,
              },
            ],
            'check_in_amount': 30,
            'check_in_time': '2030-01-15T16:20:00.000+05:30',
          },
        });
      case RunnerAppCurrentStateStub.jobInProgress:
        return _envelope('RUNNER_JOB_IN_PROGRESS', {
          'end_time':
              DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
          'payment': 'Paid',
          'payment_method': 'COD',
          'cash_to_be_collected': true,
          'cash_amount': 150,
          'job_id': 9004,
          'booking_id': 8001,
          'customer_id': 2199,
          'duration': 30,
          'lat': 19.0760,
          'lng': 72.8777,
          'address': 'Stub on-job address',
          'geo_address': 'Stub geo, India',
          'customer_name': 'Stub Customer',
          'customer_ph_no': '+919876543210',
          'show_checkout_otp': true,
          'checkout_before_mins': 15,
        });
      case RunnerAppCurrentStateStub.logout:
        return _envelope('RUNNER_LOGOUT', {
          'date': 'Sunday 23rd June',
          'shift_time': '10:00 am - 06:00 pm',
          'type': 'TOMORROW',
          'logout_pending_warning': false,
        });
      case RunnerAppCurrentStateStub.lunch:
        final lunchNow = DateTime.now();
        return _envelope(AppStrings.lunchWidgetName, {
          'cooldown_start_time': lunchNow.toIso8601String(),
          'cooldown_duration': 2,
          'start_time':
              lunchNow.add(const Duration(minutes: 2)).toIso8601String(),
          'duration': 30,
          // Band thresholds the Flutter countdown widget reads
          // (`countdown_timer_widget.dart` `greenStateDuration` etc.); the real
          // backend always sends them, so the stub does too. The KMP card
          // derives its band from the remaining fraction and ignores these —
          // they exist here purely for the Flutter lunch widget's amber/red steps.
          'green_state_duration': 30,
          'amber_state_duration': 15,
          'red_state_duration': 5,
        });
      case RunnerAppCurrentStateStub.lunchRequest:
        return _envelope(AppStrings.lunchBreakRequest, {});
      case RunnerAppCurrentStateStub.lunchCooldown:
        final cd = DateTime.now();
        return _envelope(AppStrings.lunchCoolDownWidgetName, {
          'cooldown_start_time':
              cd.subtract(const Duration(minutes: 3)).toIso8601String(),
          'cooldown_duration': 15,
          'start_time': cd.add(const Duration(minutes: 12)).toIso8601String(),
          'duration': 30,
        });
      case RunnerAppCurrentStateStub.postCheckout:
        return _envelope(AppStrings.postCheckoutWidgetName, {
          'job_id': 9005,
          'payout_info': {
            'total_earning': 350,
            'breakdown': [
              {
                'title': {'key': 'work', 'default_text': 'Work'},
                'pill_text': '1 hr',
                'amount': 250,
              },
              {
                'title': {
                  'key': 'long_distance_label',
                  'default_text': 'Long Distance'
                },
                'pill_text': '1.2 kms',
                'amount': 20,
              },
              {
                'title': {
                  'key': 'summer_bonus',
                  'default_text': 'Summer Bonus'
                },
                'icon_url':
                    'https://assets-expert.snabbit.com/payouts/nudges/red_card_straight.png',
                'pill_text': '1 hr + 15 min',
                'amount': 30,
              },
              {
                'title': {'key': 'ot_label', 'default_text': 'OT'},
                'pill_text': '15 min',
                'amount': 50,
              },
            ],
            'check_in_amount': 30,
            'check_in_time': '2030-01-15T16:25:00.000+05:30',
            'actual_check_in_time': '2030-01-15T16:20:00.000+05:30',
          },
        });
      case RunnerAppCurrentStateStub.preMarkArrival:
        return _envelope(AppStrings.preMarkArrival, {
          AppStrings.expectedEta: 15,
          AppStrings.breakDuration: 20,
          AppStrings.jobId: 9006,
        });
      case RunnerAppCurrentStateStub.errorWidget:
        return _envelope('ERROR_WIDGET', {
          'message': 'Stub error from RunnerAppCurrentStateStubs',
        });
    }
  }
}

/// Sets [GlobalState.debugStubRunnerAppCurrentStateBody] in debug builds only.
void applyDebugRunnerAppCurrentStateStub(RunnerAppCurrentStateStub stub) {
  if (!kDebugMode) return;
  GlobalState().debugStubRunnerAppCurrentStateBody =
      Map<String, dynamic>.from(RunnerAppCurrentStateStubs.body(stub));
}

/// Clears the stub so the real API is used again (debug builds).
void clearDebugRunnerAppCurrentStateStub() {
  if (!kDebugMode) return;
  GlobalState().debugStubRunnerAppCurrentStateBody = null;
}

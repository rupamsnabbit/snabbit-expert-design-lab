import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/models/period_leave_availability.dart';
import 'package:snabbit_runner/services/bcp/bcp_gate.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/profile_sync_channel.dart';
import 'package:snabbit_runner/services/runner_http.dart';

class PeriodLeaveProvider with ChangeNotifier {
  static const String _availabilityPath =
      'api/v1/runners/me/period_leave/availability';

  int periodLeaveTotal = 0;
  int periodLeaveRemaining = 0;
  bool? _availableFromBackend;
  bool _degradedFromBcp = false;

  bool get periodLeaveAvailable =>
      _availableFromBackend ?? (periodLeaveRemaining > 0);

  /// True when the most recent availability fetch failed AND the BCP gate is
  /// currently blocking [_availabilityPath]. Read by UI surfaces that want to
  /// show a "temporarily unavailable" message instead of silently hiding the
  /// option.
  bool get degradedFromBcp => _degradedFromBcp;

  void _applyParsed(PeriodLeaveAvailability parsed) {
    periodLeaveTotal = parsed.periodLeaveTotal;
    periodLeaveRemaining = parsed.periodLeaveRemaining;
    _availableFromBackend = parsed.availableFromBackend;
    _degradedFromBcp = false;
    notifyListeners();
  }

  void _markFetchFailed() {
    final wasDegraded = _degradedFromBcp;
    _degradedFromBcp = BcpGate.instance.isBlocked(_availabilityPath);
    if (_degradedFromBcp != wasDegraded) notifyListeners();
  }

  Future<void> fetchAvailability() async {
    try {
      final response = await RunnerHttp.periodLeaveAvailability();
      if (response == null || response.statusCode != 200) {
        _markFetchFailed();
        return;
      }
      final raw = response.data;
      if (raw is! Map) {
        _markFetchFailed();
        return;
      }
      final map =
          raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw);
      _applyParsed(PeriodLeaveAvailability.fromJson(map));
      // Mirror the period-leave body to the native KMP PeriodLeaveStore (Profile header
      // chip) — Dart owns the fetch; KMP reads. Best-effort (the channel swallows+logs).
      await ProfileSyncChannel.pushPeriodLeave(jsonEncode(map));
    } catch (e, st) {
      _markFetchFailed();
      MonitoringServiceHelper.logError('periodLeave_fetchAvailability_failed', {
        'error': e.toString(),
        'stackTrace': st.toString(),
      });
    }
  }

  @visibleForTesting
  void applyParsedForTest(PeriodLeaveAvailability parsed) =>
      _applyParsed(parsed);

  @visibleForTesting
  void markFetchFailedForTest() => _markFetchFailed();
}

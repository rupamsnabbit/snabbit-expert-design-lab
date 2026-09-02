import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/period_leave_availability.dart';

void main() {
  group('PeriodLeaveAvailability', () {
    test('fromJson maps snake_case and computes remaining', () {
      final m = PeriodLeaveAvailability.fromJson({
        'max_period_leaves': 3,
        'period_leaves_taken': 1,
        'available': true,
      });
      expect(m.maxPeriodLeaves, 3);
      expect(m.periodLeavesTaken, 1);
      expect(m.periodLeaveTotal, 3);
      expect(m.periodLeaveRemaining, 2);
      expect(m.availableFromBackend, true);
      expect(m.periodLeaveAvailable, true);
    });

    test('fromJson accepts camelCase keys', () {
      final m = PeriodLeaveAvailability.fromJson({
        'maxPeriodLeaves': 2,
        'periodLeavesTaken': 2,
      });
      expect(m.periodLeaveRemaining, 0);
      expect(m.periodLeaveAvailable, false);
    });

    test('clamps negative remaining when taken exceeds max', () {
      final m = PeriodLeaveAvailability.fromJson({
        'max_period_leaves': 2,
        'period_leaves_taken': 5,
      });
      expect(m.periodLeaveRemaining, 0);
    });

    test('available string true and false', () {
      final t = PeriodLeaveAvailability.fromJson({
        'max_period_leaves': 1,
        'period_leaves_taken': 0,
        'available': 'true',
      });
      expect(t.availableFromBackend, true);

      final f = PeriodLeaveAvailability.fromJson({
        'max_period_leaves': 1,
        'period_leaves_taken': 0,
        'available': 'false',
      });
      expect(f.availableFromBackend, false);
    });

    test('periodLeaveAvailable uses backend when present', () {
      final m = PeriodLeaveAvailability.fromJson({
        'max_period_leaves': 5,
        'period_leaves_taken': 0,
        'available': false,
      });
      expect(m.periodLeaveAvailable, false);
    });

    test('periodLeaveAvailable falls back when backend absent', () {
      final m = PeriodLeaveAvailability.fromJson({
        'max_period_leaves': 3,
        'period_leaves_taken': 1,
      });
      expect(m.availableFromBackend, isNull);
      expect(m.periodLeaveAvailable, true);
    });

    test('missing keys default counts to zero', () {
      final m = PeriodLeaveAvailability.fromJson({});
      expect(m.periodLeaveRemaining, 0);
      expect(m.periodLeaveAvailable, false);
    });
  });
}

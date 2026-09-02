// Unit tests for lib/services/job_http.dart
//
// NOTE: JobHttp methods are static and use singletons (HttpService(), GlobalState()),
// which makes them hard to mock without refactoring to dependency injection.
// Mirrors the skip pattern used in test/unit/referrals/services/referral_http_test.dart.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JobHttp', () {
    group('changeAttendance (static)', () {
      test('posts to api/v1/runners/me/attendance/mark with body forwarded',
          () async {
        // Arrange / Act / Assert: requires HttpService DI to verify the URL
        // and body. Tracked alongside the broader HTTP-test refactor.
      },
          skip:
              'TODO: Set up mocks for external dependencies (HttpService, GlobalState).');

      test('returns null on exception (catch branch)', () async {
        // Same as above — needs DI on HttpService to force a throw.
      },
          skip:
              'TODO: Set up mocks for external dependencies (HttpService, GlobalState).');
    });

    group('markAttendance (static)', () {
      test('posts to api/v1/runners/me/provisional_attendance/mark', () async {
        // Pre-existing untested behavior; documented for parity with changeAttendance.
      },
          skip:
              'TODO: Set up mocks for external dependencies (HttpService, GlobalState).');
    });
  });
}

/**
 * Unit tests for lib/services/runner_http.dart
 *
 * COVERAGE REQUIREMENTS (mirrored from Python agent philosophy):
 * - ✅ **Branch Coverage: 100% (REQUIRED)** - Every if/else/try/catch must be tested
 * - 📊 **Line Coverage: 70% (Important - business logic)** - Based on code criticality
 *
 * Testing Philosophy (from repository standards):
 * - 100% branch coverage (strict requirement)
 * - Pragmatic line coverage based on module type
 * - Fewer, comprehensive tests over many small tests
 * - Test all branches: if/else, try/catch, conditional operators
 *
 * All tests follow:
 * - AAA pattern (Arrange-Act-Assert)
 * - Builder pattern for test data
 * - Mock external dependencies (DB, APIs, etc.)
 * - group() for organizing related tests
 *
 * CRITICAL REQUIREMENTS:
 * 1. 100% branch coverage is NON-NEGOTIABLE - test both paths of every if/else
 * 2. Test exception handling - both success and error paths
 * 3. Test edge cases - null values, empty collections, boundary conditions
 * 4. Mock all external dependencies - no real DB/API calls
 *
 * Next steps:
 * 1. Fill in TODO comments with specific test logic
 * 2. Add matchers to verify expected behavior for EACH branch
 * 3. Mock external dependencies (database, API clients, etc.)
 * 4. Run `flutter test` to verify all tests pass
 * 5. Run `flutter test --coverage` to verify 100% branch coverage
 */

import 'package:flutter_test/flutter_test.dart';
// import 'package:mockito/mockito.dart';
// import 'package:mockito/annotations.dart';
// NOTE: Static methods using singletons (HttpService(), GlobalState()) are hard to mock.
// Consider refactoring to use dependency injection or write integration tests.
// NOTE: Most Flutter tests handle async automatically
import 'package:snabbit_runner/services/runner_http.dart';
import 'runner_http_builder.dart';

void main() {
  group('RunnerHttp', () {
    // NOTE: runnerBasic method has been removed/commented out from RunnerHttp

    group('runnersMe (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnersMe(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnersMe(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerReferral (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerReferral(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerReferral(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 4)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerRegistration (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerRegistration(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerRegistration(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 4)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('editDetailsReviewAction (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.editDetailsReviewAction(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.editDetailsReviewAction(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 4)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerRegistrationPreviousStep (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerRegistrationPreviousStep(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerRegistrationPreviousStep(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 4)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerAppCurrentState (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerAppCurrentState(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerAppCurrentState(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 4)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerDocuments (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerDocuments(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerDocuments(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnersMeHelpline (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnersMeHelpline(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnersMeHelpline(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerHouseTasks (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerHouseTasks(jobId: 1);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerHouseTasks(jobId: 0);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerSubmitHouseTasks (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerSubmitHouseTasks(jobId: 1);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerSubmitHouseTasks(jobId: 1);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerAddReferral (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerAddReferral(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerAddReferral(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerAddMultipleReferrals (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerAddMultipleReferrals(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerAddMultipleReferrals(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerReferrals (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerReferrals(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerReferrals(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('resendRegistrationCode (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.resendRegistrationCode(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.resendRegistrationCode(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 4)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerReferralsDetails (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerReferralsDetails(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerReferralsDetails(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerCustomerRating (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerCustomerRating(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerCustomerRating(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 9)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('runnerSOS (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.runnerSOS(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.runnerSOS(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('uploadContactsFile (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.uploadContactsFile('/tmp/contacts.json');

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.uploadContactsFile('/tmp/contacts.json');

        // Assert
        // TODO: Assert edge case behavior (branches: 4)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('uploadAppsFile (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.uploadAppsFile('/tmp/apps.json');

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.uploadAppsFile('/tmp/apps.json');

        // Assert
        // TODO: Assert edge case behavior (branches: 3)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('markArrival (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.markArrival('/tmp/arrival.jpg', 1);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.markArrival(null, null);

        // Assert
        // TODO: Assert edge case behavior (branches: 7)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('shiftLogin (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.shiftLogin(null);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.shiftLogin(null);

        // Assert
        // TODO: Assert edge case behavior (branches: 5)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    // NOTE: runnerLoginLocation method has been removed from RunnerHttp

    group('goLive (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.goLive(null);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.goLive(null);

        // Assert
        // TODO: Assert edge case behavior (branches: 4)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('getPrivacyPolicy (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.getPrivacyPolicy(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.getPrivacyPolicy(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 2)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('todayShiftPerformance (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.todayShiftPerformance(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.todayShiftPerformance(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 3)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('fetchInfoBanners (static)', () {
      test('returns expected result for valid input', () async {
        // Arrange
        // TODO: Add valid input parameters
        // NOTE: If this method uses singletons (HttpService(), GlobalState(), etc.),
        // consider refactoring to use dependency injection or mark as integration test.

        // Act
        final result = await RunnerHttp.fetchInfoBanners(/* TODO: params */);

        // Assert
        expect(result, isNotNull);
        // TODO: Add specific assertions
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        // Arrange - test branch coverage
        // TODO: Add edge case parameters

        // Act
        final result = await RunnerHttp.fetchInfoBanners(/* TODO: params */);

        // Assert
        // TODO: Assert edge case behavior (branches: 4)
      }, skip: 'TODO: Set up mocks for external dependencies');
    });

    group('periodLeaveAvailability (static)', () {
      test('returns expected result for valid input', () async {
        final result = await RunnerHttp.periodLeaveAvailability();

        expect(result, isNotNull);
      }, skip: 'TODO: Set up mocks for external dependencies (HttpService, GlobalState, etc.)');
      test('handles error/edge cases correctly', () async {
        final result = await RunnerHttp.periodLeaveAvailability();

        expect(result, isNotNull);
      }, skip: 'TODO: Set up mocks for external dependencies');
    });
  });
}

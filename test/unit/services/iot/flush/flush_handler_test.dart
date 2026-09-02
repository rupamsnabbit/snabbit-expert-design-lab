// Unit tests for FlushHandler class
// Tests the flush operations including:
// - Regular flush (send and cleanup old data)
// - Flush and delete all (send and delete all user data)
//
// SNCON-91: IoT Flush Handler Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/services/iot/cleanup/cleanup_job.dart';
import 'package:snabbit_runner/services/iot/flush/flush_handler.dart';
import 'package:snabbit_runner/services/iot/sender/sender.dart';

import 'flush_handler_test.mocks.dart';

// Generate mocks for dependencies
@GenerateMocks([Sender, CleanupJob])
void main() {
  group('FlushHandler', () {
    late FlushHandler flushHandler;
    late MockSender mockSender;
    late MockCleanupJob mockCleanupJob;

    const testUserId = 'test-user-123';
    const testIotEndpoint = 'https://api.example.com/iot';

    setUp(() {
      mockSender = MockSender();
      mockCleanupJob = MockCleanupJob();
      flushHandler = FlushHandler(
        sender: mockSender,
        cleanupJob: mockCleanupJob,
      );
    });

    group('flush', () {
      test('should successfully flush and cleanup data', () async {
        // - Mock sender.sendAllData to return a count
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 5);
        // - Mock cleanupJob.cleanupAllData to return a count
        when(mockCleanupJob.cleanupAllData(any))
            .thenAnswer((_) async => 3);

        // - Call flush with test parameters
        final result = await flushHandler.flush(
          testUserId,
          testIotEndpoint,
        );

        // - Verify both methods were called with correct parameters
        verify(mockSender.sendAllData(
          testUserId,
          testIotEndpoint,
        )).called(1);
        verify(mockCleanupJob.cleanupAllData(testUserId)).called(1);

        // - Verify returns true
        expect(result, true);
      });

      test('should return true when both steps complete', () async {
        // - Mock sender.sendAllData to return 5
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 5);
        // - Mock cleanupJob.cleanupAllData to return 3
        when(mockCleanupJob.cleanupAllData(any))
            .thenAnswer((_) async => 3);

        // - Call flush
        final result = await flushHandler.flush(
          testUserId,
          testIotEndpoint,
        );

        // - Verify result is true
        expect(result, true);
      });

      test('should call sender.sendAllData first', () async {
        // - Mock both methods
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 2);
        when(mockCleanupJob.cleanupAllData(any))
            .thenAnswer((_) async => 1);

        // - Call flush
        await flushHandler.flush(
          testUserId,
          testIotEndpoint,
        );

        // - Use verifyInOrder to ensure sender.sendAllData is called before cleanupJob.cleanupAllData
        // - Verify order of execution
        verifyInOrder([
          mockSender.sendAllData(
            testUserId,
            testIotEndpoint,
          ),
          mockCleanupJob.cleanupAllData(testUserId),
        ]);
      });

      test('should call cleanupJob.cleanupAllData second', () async {
        // - Mock both methods
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 4);
        when(mockCleanupJob.cleanupAllData(any))
            .thenAnswer((_) async => 2);

        // - Call flush
        await flushHandler.flush(
          testUserId,
          testIotEndpoint,
        );

        // - Use verifyInOrder to ensure cleanupJob.cleanupAllData is called after sender.sendAllData
        // - Verify order of execution
        verifyInOrder([
          mockSender.sendAllData(
            testUserId,
            testIotEndpoint,
          ),
          mockCleanupJob.cleanupAllData(testUserId),
        ]);
      });

      test('should return true even when sentCount is 0', () async {
        // - Mock sender.sendAllData to return 0
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 0);
        // - Mock cleanupJob.cleanupAllData to return 0
        when(mockCleanupJob.cleanupAllData(any))
            .thenAnswer((_) async => 0);

        // - Call flush
        final result = await flushHandler.flush(
          testUserId,
          testIotEndpoint,
        );

        // - Verify result is true (flush completes even with no data)
        expect(result, true);
      });

      test('should return false on exception', () async {
        // - Mock sender.sendAllData to throw an exception
        when(mockSender.sendAllData(any, any))
            .thenThrow(Exception('Send failed'));

        // - Call flush
        final result = await flushHandler.flush(
          testUserId,
          testIotEndpoint,
        );

        // - Verify result is false
        expect(result, false);
      });

      test('should pass correct userId to both sender and cleanup', () async {
        // - Mock both methods
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 3);
        when(mockCleanupJob.cleanupAllData(any))
            .thenAnswer((_) async => 2);

        // - Call flush with testUserId
        await flushHandler.flush(
          testUserId,
          testIotEndpoint,
        );

        // - Verify sender.sendAllData was called with testUserId
        verify(mockSender.sendAllData(
          testUserId,
          testIotEndpoint,
        )).called(1);

        // - Verify cleanupJob.cleanupAllData was called with testUserId
        verify(mockCleanupJob.cleanupAllData(testUserId)).called(1);
      });

      test('should pass correct endpoint to sender', () async {
        // - Mock sender.sendAllData
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 6);
        when(mockCleanupJob.cleanupAllData(any))
            .thenAnswer((_) async => 1);

        // - Call flush with test endpoint
        await flushHandler.flush(
          testUserId,
          testIotEndpoint,
        );

        // - Verify sender.sendAllData was called with testIotEndpoint
        verify(mockSender.sendAllData(
          testUserId,
          testIotEndpoint,
        )).called(1);
      });
    });

    group('flushAndDeleteAll', () {
      test('should successfully send and delete all data', () async {
        // - Mock sender.sendAllData to return a count
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 7);
        // - Mock cleanupJob.deleteAllUserData to complete successfully
        when(mockCleanupJob.deleteAllUserData(any))
            .thenAnswer((_) async => 15);

        // - Call flushAndDeleteAll with test parameters
        final result = await flushHandler.flushAndDeleteAll(
          testUserId,
          testIotEndpoint,
        );

        // - Verify both methods were called with correct parameters
        verify(mockSender.sendAllData(
          testUserId,
          testIotEndpoint,
        )).called(1);
        verify(mockCleanupJob.deleteAllUserData(testUserId)).called(1);

        // - Verify returns true
        expect(result, true);
      });

      test('should return true when both steps complete', () async {
        // - Mock sender.sendAllData to return 5
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 5);
        // - Mock cleanupJob.deleteAllUserData to complete
        when(mockCleanupJob.deleteAllUserData(any))
            .thenAnswer((_) async => 10);

        // - Call flushAndDeleteAll
        final result = await flushHandler.flushAndDeleteAll(
          testUserId,
          testIotEndpoint,
        );

        // - Verify result is true
        expect(result, true);
      });

      test('should call sender.sendAllData first', () async {
        // - Mock both methods
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 3);
        when(mockCleanupJob.deleteAllUserData(any))
            .thenAnswer((_) async => 8);

        // - Call flushAndDeleteAll
        await flushHandler.flushAndDeleteAll(
          testUserId,
          testIotEndpoint,
        );

        // - Use verifyInOrder to ensure sender.sendAllData is called before cleanupJob.deleteAllUserData
        // - Verify order of execution
        verifyInOrder([
          mockSender.sendAllData(
            testUserId,
            testIotEndpoint,
          ),
          mockCleanupJob.deleteAllUserData(testUserId),
        ]);
      });

      test('should call cleanupJob.deleteAllUserData second', () async {
        // - Mock both methods
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 6);
        when(mockCleanupJob.deleteAllUserData(any))
            .thenAnswer((_) async => 12);

        // - Call flushAndDeleteAll
        await flushHandler.flushAndDeleteAll(
          testUserId,
          testIotEndpoint,
        );

        // - Use verifyInOrder to ensure cleanupJob.deleteAllUserData is called after sender.sendAllData
        // - Verify order of execution
        verifyInOrder([
          mockSender.sendAllData(
            testUserId,
            testIotEndpoint,
          ),
          mockCleanupJob.deleteAllUserData(testUserId),
        ]);
      });

      test('should still delete data even if send fails', () async {
        // - Mock sender.sendAllData to throw an exception
        when(mockSender.sendAllData(any, any))
            .thenThrow(Exception('Send failed'));
        // - Mock cleanupJob.deleteAllUserData to complete successfully
        when(mockCleanupJob.deleteAllUserData(any))
            .thenAnswer((_) async => 20);

        // - Call flushAndDeleteAll
        final result = await flushHandler.flushAndDeleteAll(
          testUserId,
          testIotEndpoint,
        );

        // - Verify cleanupJob.deleteAllUserData was still called
        verify(mockCleanupJob.deleteAllUserData(testUserId)).called(1);

        // - Verify result is false (overall operation failed)
        expect(result, false);
      });

      test('should return false when both send and delete fail', () async {
        // - Mock sender.sendAllData to throw an exception
        when(mockSender.sendAllData(any, any))
            .thenThrow(Exception('Send failed'));
        // - Mock cleanupJob.deleteAllUserData to throw an exception
        when(mockCleanupJob.deleteAllUserData(any))
            .thenThrow(Exception('Delete failed'));

        // - Call flushAndDeleteAll
        final result = await flushHandler.flushAndDeleteAll(
          testUserId,
          testIotEndpoint,
        );

        // - Verify result is false
        expect(result, false);
      });

      test('should pass correct userId to both sender and cleanup', () async {
        // - Mock both methods
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 4);
        when(mockCleanupJob.deleteAllUserData(any))
            .thenAnswer((_) async => 9);

        // - Call flushAndDeleteAll with testUserId
        await flushHandler.flushAndDeleteAll(
          testUserId,
          testIotEndpoint,
        );

        // - Verify sender.sendAllData was called with testUserId
        verify(mockSender.sendAllData(
          testUserId,
          testIotEndpoint,
        )).called(1);

        // - Verify cleanupJob.deleteAllUserData was called with testUserId
        verify(mockCleanupJob.deleteAllUserData(testUserId)).called(1);
      });

      test('should pass correct endpoint to sender', () async {
        // - Mock sender.sendAllData
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 8);
        when(mockCleanupJob.deleteAllUserData(any))
            .thenAnswer((_) async => 5);

        // - Call flushAndDeleteAll with test endpoint
        await flushHandler.flushAndDeleteAll(
          testUserId,
          testIotEndpoint,
        );

        // - Verify sender.sendAllData was called with testIotEndpoint
        verify(mockSender.sendAllData(
          testUserId,
          testIotEndpoint,
        )).called(1);
      });

      test('should not pass endpoint to deleteAllUserData', () async {
        // - Mock cleanupJob.deleteAllUserData
        when(mockSender.sendAllData(any, any))
            .thenAnswer((_) async => 2);
        when(mockCleanupJob.deleteAllUserData(any))
            .thenAnswer((_) async => 11);

        // - Call flushAndDeleteAll
        await flushHandler.flushAndDeleteAll(
          testUserId,
          testIotEndpoint,
        );

        // - Verify deleteAllUserData was called with only userId (no endpoint)
        verify(mockCleanupJob.deleteAllUserData(testUserId)).called(1);
      });
    });
  });
}

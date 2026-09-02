/**
 * Unit tests for CleanupJob
 *
 * Purpose: Test cleanup operations for IoT data (battery and location)
 *
 * Two cleanup strategies:
 * 1. Post-send cleanup (cleanupSentData): Delete sent records after successful API
 * 2. Periodic cleanup (cleanupAllData): Enforce max limits using FIFO (oldest first)
 *    regardless of sent status - for offline/network failure scenarios
 *
 * Related: SNCON-91 - IoT tracking system
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/iot/cleanup/cleanup_job.dart';
import 'package:snabbit_runner/services/iot/config/config_service.dart';

// Generate mocks for dependencies
@GenerateMocks([
  IDatabaseInterface,
  ConfigService,
])
import 'cleanup_job_test.mocks.dart';

void main() {
  group('CleanupJob', () {
    late MockIDatabaseInterface mockDb;
    late MockConfigService mockConfig;
    late CleanupJob cleanupJob;

    const String testUserId = 'user-123';
    const int defaultMaxBatteryRecords = 1000;
    const int defaultMaxLocationRecords = 1000;
    const int defaultMaxDeviceStateRecords = 1000;

    setUp(() {
      mockDb = MockIDatabaseInterface();
      mockConfig = MockConfigService();

      // Set default config values
      when(mockConfig.maxBatteryRecords).thenReturn(defaultMaxBatteryRecords);
      when(mockConfig.maxLocationRecords).thenReturn(defaultMaxLocationRecords);
      when(mockConfig.maxDeviceStateRecords).thenReturn(defaultMaxDeviceStateRecords);

      cleanupJob = CleanupJob(
        database: mockDb,
        config: mockConfig,
      );
    });

    // ========================================================================
    // POST-SEND CLEANUP TESTS: Delete sent records after successful API send
    // ========================================================================

    group('cleanupSentBatteryData', () {
      test('should delete all sent battery records for user', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 50);

        final result = await cleanupJob.cleanupSentBatteryData(testUserId);

        expect(result, 50);
        verify(mockDb.delete(
          DatabaseTables.battery,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [testUserId, 1],
        )).called(1);
      });

      test('should return 0 when no sent records exist', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);

        final result = await cleanupJob.cleanupSentBatteryData(testUserId);

        expect(result, 0);
      });

      test('should handle exception and return 0', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('Database error'));

        final result = await cleanupJob.cleanupSentBatteryData(testUserId);

        expect(result, 0);
      });
    });

    group('cleanupSentLocationData', () {
      test('should delete all sent location records for user', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 80);

        final result = await cleanupJob.cleanupSentLocationData(testUserId);

        expect(result, 80);
        verify(mockDb.delete(
          DatabaseTables.location,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [testUserId, 1],
        )).called(1);
      });

      test('should return 0 when no sent records exist', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);

        final result = await cleanupJob.cleanupSentLocationData(testUserId);

        expect(result, 0);
      });

      test('should handle exception and return 0', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('Database error'));

        final result = await cleanupJob.cleanupSentLocationData(testUserId);

        expect(result, 0);
      });
    });

    group('cleanupSentDeviceStateData', () {
      test('should delete all sent device state records for user', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 60);

        final result = await cleanupJob.cleanupSentDeviceStateData(testUserId);

        expect(result, 60);
        verify(mockDb.delete(
          DatabaseTables.deviceState,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [testUserId, 1],
        )).called(1);
      });

      test('should return 0 when no sent records exist', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);

        final result = await cleanupJob.cleanupSentDeviceStateData(testUserId);

        expect(result, 0);
      });

      test('should handle exception and return 0', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('Database error'));

        final result = await cleanupJob.cleanupSentDeviceStateData(testUserId);

        expect(result, 0);
      });
    });

    group('cleanupSentData', () {
      test('should cleanup battery, location, and device state sent data', () async {
        when(mockDb.delete(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 30);
        when(mockDb.delete(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 50);
        when(mockDb.delete(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 20);

        final result = await cleanupJob.cleanupSentData(testUserId);

        expect(result, 100);
      });
    });

    // ========================================================================
    // PERIODIC CLEANUP TESTS: Enforce max limits using FIFO (oldest first)
    // ========================================================================

    group('cleanupBatteryData (periodic FIFO cleanup)', () {
      test('should delete oldest records when exceeding limit', () async {
        // Total = 1500, Max = 1000, need to delete 500 oldest
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1500);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        const expectedRecordsToDelete = 1500 - defaultMaxBatteryRecords; // 500

        final result = await cleanupJob.cleanupBatteryData(testUserId);

        expect(result, expectedRecordsToDelete);

        // Verify execute called with DELETE SQL (no sent filter - FIFO all records)
        final captured = verify(mockDb.execute(captureAny, captureAny)).captured;
        final sql = captured[0] as String;
        final whereArgs = captured[1] as List;

        expect(sql, contains('DELETE FROM ${DatabaseTables.battery}'));
        expect(sql, contains('WHERE user_id = ?'));
        expect(sql, isNot(contains('sent'))); // No sent filter - deletes oldest regardless
        expect(sql, contains('ORDER BY collected_at ASC'));
        expect(sql, contains('LIMIT ?'));
        expect(whereArgs, [testUserId, expectedRecordsToDelete]);
      });

      test('should return 0 when under limit', () async {
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 500);

        final result = await cleanupJob.cleanupBatteryData(testUserId);

        expect(result, 0);
        verifyNever(mockDb.execute(any, any));
      });

      test('should return 0 when count equals limit exactly', () async {
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => defaultMaxBatteryRecords);

        final result = await cleanupJob.cleanupBatteryData(testUserId);

        expect(result, 0);
        verifyNever(mockDb.execute(any, any));
      });

      test('should handle exception and return 0', () async {
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('Database error'));

        final result = await cleanupJob.cleanupBatteryData(testUserId);

        expect(result, 0);
      });

      test('should use config maxBatteryRecords value', () async {
        when(mockConfig.maxBatteryRecords).thenReturn(500);
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 700);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        await cleanupJob.cleanupBatteryData(testUserId);

        verify(mockConfig.maxBatteryRecords).called(1);
        final captured = verify(mockDb.execute(captureAny, captureAny)).captured;
        final whereArgs = captured[1] as List;
        expect(whereArgs[1], 200); // 700 - 500 = 200
      });

      test('should delete oldest records first (ORDER BY collected_at ASC)', () async {
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1300);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        await cleanupJob.cleanupBatteryData(testUserId);

        final captured = verify(mockDb.execute(captureAny, captureAny)).captured;
        final sql = captured[0] as String;
        expect(sql, contains('ORDER BY collected_at ASC'));
      });
    });

    group('cleanupLocationData (periodic FIFO cleanup)', () {
      test('should delete oldest records when exceeding limit', () async {
        // Total = 2000, Max = 1000, need to delete 1000 oldest
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 2000);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        const expectedRecordsToDelete = 2000 - defaultMaxLocationRecords; // 1000

        final result = await cleanupJob.cleanupLocationData(testUserId);

        expect(result, expectedRecordsToDelete);

        // Verify execute called with DELETE SQL (no sent filter - FIFO all records)
        final captured = verify(mockDb.execute(captureAny, captureAny)).captured;
        final sql = captured[0] as String;
        final whereArgs = captured[1] as List;

        expect(sql, contains('DELETE FROM ${DatabaseTables.location}'));
        expect(sql, contains('WHERE user_id = ?'));
        expect(sql, isNot(contains('sent'))); // No sent filter - deletes oldest regardless
        expect(sql, contains('ORDER BY collected_at ASC'));
        expect(sql, contains('LIMIT ?'));
        expect(whereArgs, [testUserId, expectedRecordsToDelete]);
      });

      test('should return 0 when under limit', () async {
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 300);

        final result = await cleanupJob.cleanupLocationData(testUserId);

        expect(result, 0);
        verifyNever(mockDb.execute(any, any));
      });

      test('should return 0 when count equals limit exactly', () async {
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => defaultMaxLocationRecords);

        final result = await cleanupJob.cleanupLocationData(testUserId);

        expect(result, 0);
        verifyNever(mockDb.execute(any, any));
      });

      test('should handle exception and return 0', () async {
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('Database error'));

        final result = await cleanupJob.cleanupLocationData(testUserId);

        expect(result, 0);
      });

      test('should use config maxLocationRecords value', () async {
        when(mockConfig.maxLocationRecords).thenReturn(800);
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1200);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        await cleanupJob.cleanupLocationData(testUserId);

        verify(mockConfig.maxLocationRecords).called(1);
        final captured = verify(mockDb.execute(captureAny, captureAny)).captured;
        final whereArgs = captured[1] as List;
        expect(whereArgs[1], 400); // 1200 - 800 = 400
      });

      test('should delete oldest records first (ORDER BY collected_at ASC)', () async {
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1600);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        await cleanupJob.cleanupLocationData(testUserId);

        final captured = verify(mockDb.execute(captureAny, captureAny)).captured;
        final sql = captured[0] as String;
        expect(sql, contains('ORDER BY collected_at ASC'));
      });
    });

    group('cleanupDeviceStateData (periodic FIFO cleanup)', () {
      test('should delete oldest records when exceeding limit', () async {
        // Total = 1800, Max = 1000, need to delete 800 oldest
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1800);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        const expectedRecordsToDelete = 1800 - defaultMaxDeviceStateRecords; // 800

        final result = await cleanupJob.cleanupDeviceStateData(testUserId);

        expect(result, expectedRecordsToDelete);

        // Verify execute called with DELETE SQL (no sent filter - FIFO all records)
        final captured = verify(mockDb.execute(captureAny, captureAny)).captured;
        final sql = captured[0] as String;
        final whereArgs = captured[1] as List;

        expect(sql, contains('DELETE FROM ${DatabaseTables.deviceState}'));
        expect(sql, contains('WHERE user_id = ?'));
        expect(sql, isNot(contains('sent'))); // No sent filter - deletes oldest regardless
        expect(sql, contains('ORDER BY collected_at ASC'));
        expect(sql, contains('LIMIT ?'));
        expect(whereArgs, [testUserId, expectedRecordsToDelete]);
      });

      test('should return 0 when under limit', () async {
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 400);

        final result = await cleanupJob.cleanupDeviceStateData(testUserId);

        expect(result, 0);
        verifyNever(mockDb.execute(any, any));
      });

      test('should return 0 when count equals limit exactly', () async {
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => defaultMaxDeviceStateRecords);

        final result = await cleanupJob.cleanupDeviceStateData(testUserId);

        expect(result, 0);
        verifyNever(mockDb.execute(any, any));
      });

      test('should handle exception and return 0', () async {
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('Database error'));

        final result = await cleanupJob.cleanupDeviceStateData(testUserId);

        expect(result, 0);
      });

      test('should use config maxDeviceStateRecords value', () async {
        when(mockConfig.maxDeviceStateRecords).thenReturn(600);
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 900);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        await cleanupJob.cleanupDeviceStateData(testUserId);

        verify(mockConfig.maxDeviceStateRecords).called(1);
        final captured = verify(mockDb.execute(captureAny, captureAny)).captured;
        final whereArgs = captured[1] as List;
        expect(whereArgs[1], 300); // 900 - 600 = 300
      });

      test('should delete oldest records first (ORDER BY collected_at ASC)', () async {
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1400);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        await cleanupJob.cleanupDeviceStateData(testUserId);

        final captured = verify(mockDb.execute(captureAny, captureAny)).captured;
        final sql = captured[0] as String;
        expect(sql, contains('ORDER BY collected_at ASC'));
      });
    });

    group('cleanupAllData (periodic FIFO cleanup)', () {
      test('should cleanup battery, location, and device state data', () async {
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1500);
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 2000);
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1200);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        await cleanupJob.cleanupAllData(testUserId);

        verify(mockDb.count(
          DatabaseTables.battery,
          where: 'user_id = ?',
          whereArgs: [testUserId],
        )).called(1);
        verify(mockDb.count(
          DatabaseTables.location,
          where: 'user_id = ?',
          whereArgs: [testUserId],
        )).called(1);
        verify(mockDb.count(
          DatabaseTables.deviceState,
          where: 'user_id = ?',
          whereArgs: [testUserId],
        )).called(1);
      });

      test('should return total deleted count', () async {
        // Battery: 1300 - 1000 = 300 to delete
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1300);
        // Location: 1500 - 1000 = 500 to delete
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1500);
        // DeviceState: 1200 - 1000 = 200 to delete
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1200);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        final result = await cleanupJob.cleanupAllData(testUserId);

        expect(result, 300 + 500 + 200); // 1000 total
      });

      test('should return 0 when all are under limit', () async {
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 500);
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 300);
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 200);

        final result = await cleanupJob.cleanupAllData(testUserId);

        expect(result, 0);
      });

      test('should handle exception in battery cleanup gracefully', () async {
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('Battery cleanup failed'));
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1300);
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 500);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        final result = await cleanupJob.cleanupAllData(testUserId);

        // Battery failed (0), location: 1300 - 1000 = 300, device state under limit (0)
        expect(result, 300);
      });

      test('should handle exception in location cleanup gracefully', () async {
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1400);
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('Location cleanup failed'));
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 400);

        final result = await cleanupJob.cleanupAllData(testUserId);

        // Battery: 1400 - 1000 = 400, location failed (0), device state under limit (0)
        expect(result, 400);
      });

      test('should handle exception in device state cleanup gracefully', () async {
        when(mockDb.count(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 500);
        when(mockDb.count(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 1600);
        when(mockDb.count(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('DeviceState cleanup failed'));
        when(mockDb.execute(any, any)).thenAnswer((_) async => null);

        final result = await cleanupJob.cleanupAllData(testUserId);

        // Battery under limit (0), location: 1600 - 1000 = 600, device state failed (0)
        expect(result, 600);
      });
    });

    // ========================================================================
    // USER DATA DELETION TESTS: For logout/user switch
    // ========================================================================

    group('deleteAllUserData', () {
      test('should delete all battery, location, and device state records for user', () async {
        when(mockDb.delete(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 50);
        when(mockDb.delete(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 80);
        when(mockDb.delete(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 30);

        await cleanupJob.deleteAllUserData(testUserId);

        verify(mockDb.delete(
          DatabaseTables.battery,
          where: 'user_id = ?',
          whereArgs: [testUserId],
        )).called(1);
        verify(mockDb.delete(
          DatabaseTables.location,
          where: 'user_id = ?',
          whereArgs: [testUserId],
        )).called(1);
        verify(mockDb.delete(
          DatabaseTables.deviceState,
          where: 'user_id = ?',
          whereArgs: [testUserId],
        )).called(1);
      });

      test('should return total deleted count', () async {
        when(mockDb.delete(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 100);
        when(mockDb.delete(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 200);
        when(mockDb.delete(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 50);

        final result = await cleanupJob.deleteAllUserData(testUserId);

        expect(result, 350);
      });

      test('should delete all records regardless of sent status', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 10);

        await cleanupJob.deleteAllUserData(testUserId);

        // Verify no sent status filter
        verify(mockDb.delete(
          DatabaseTables.battery,
          where: 'user_id = ?',
          whereArgs: [testUserId],
        )).called(1);
        verify(mockDb.delete(
          DatabaseTables.location,
          where: 'user_id = ?',
          whereArgs: [testUserId],
        )).called(1);
        verify(mockDb.delete(
          DatabaseTables.deviceState,
          where: 'user_id = ?',
          whereArgs: [testUserId],
        )).called(1);
      });

      test('should handle exception and return 0', () async {
        when(mockDb.delete(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenThrow(Exception('Battery delete failed'));

        final result = await cleanupJob.deleteAllUserData(testUserId);

        expect(result, 0);
      });

      test('should return 0 when no records exist for user', () async {
        when(mockDb.delete(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);
        when(mockDb.delete(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);
        when(mockDb.delete(
          DatabaseTables.deviceState,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);

        final result = await cleanupJob.deleteAllUserData(testUserId);

        expect(result, 0);
      });
    });
  });
}

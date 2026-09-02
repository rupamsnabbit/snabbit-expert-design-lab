/**
 * Unit tests for IotBackgroundManager
 *
 * Purpose: Test the orchestration of IoT periodic jobs, flush, and cleanup
 * Related: SNCON-91 - IoT tracking system
 */

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/services/iot/background/iot_background_manager.dart';
import 'package:snabbit_runner/services/iot/cleanup/cleanup_job.dart';
import 'package:snabbit_runner/services/iot/collectors/battery_collector.dart';
import 'package:snabbit_runner/services/iot/collectors/device_state_collector.dart';
import 'package:snabbit_runner/services/iot/collectors/location_collector.dart';
import 'package:snabbit_runner/services/iot/config/config_service.dart';
import 'package:snabbit_runner/services/iot/sender/sender.dart';

// Generate mocks for dependencies
@GenerateMocks([
  ConfigService,
  BatteryCollector,
  LocationCollector,
  DeviceStateCollector,
  Sender,
  CleanupJob,
])
import 'iot_background_manager_test.mocks.dart';

void main() {
  group('IotBackgroundManager', () {
    late MockConfigService mockConfig;
    late MockBatteryCollector mockBatteryCollector;
    late MockLocationCollector mockLocationCollector;
    late MockDeviceStateCollector mockDeviceStateCollector;
    late MockSender mockSender;
    late MockCleanupJob mockCleanupJob;
    late IotBackgroundManager manager;

    const String testUserId = 'user-123';
    const String testEndpoint = 'https://api.example.com/iot';
    const String testRunnerStatus = 'available';

    setUp(() {
      mockConfig = MockConfigService();
      mockBatteryCollector = MockBatteryCollector();
      mockLocationCollector = MockLocationCollector();
      mockDeviceStateCollector = MockDeviceStateCollector();
      mockSender = MockSender();
      mockCleanupJob = MockCleanupJob();

      // Default config values
      when(mockConfig.apiEnabled).thenReturn(true);
      when(mockConfig.batteryCollectionInterval).thenReturn(60);
      when(mockConfig.cleanupInterval).thenReturn(3600);
      when(mockConfig.getLocationInterval(any)).thenReturn(30);
      when(mockConfig.deviceStateCollectionInterval).thenReturn(60);
      when(mockConfig.refresh()).thenAnswer((_) async {});

      manager = IotBackgroundManager(
        config: mockConfig,
        batteryCollector: mockBatteryCollector,
        locationCollector: mockLocationCollector,
        sender: mockSender,
        cleanupJob: mockCleanupJob,
        deviceStateCollector: mockDeviceStateCollector,
      );
    });

    // ========================================================================
    // runPeriodicJobs TESTS
    // ========================================================================

    group('runPeriodicJobs', () {
      test('should skip all jobs when API is disabled', () async {
        when(mockConfig.apiEnabled).thenReturn(false);

        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        // Verify config was refreshed
        verify(mockConfig.refresh()).called(1);

        // Verify no jobs were run
        verifyNever(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId')));
        verifyNever(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId')));
        verifyNever(mockSender.sendAllData(any, any));
        verifyNever(mockCleanupJob.cleanupAllData(any));
        verifyNever(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId')));
      });

      test('should refresh config before running jobs', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        verify(mockConfig.refresh()).called(1);
      });

      test('should run battery collection on first call', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        verify(mockBatteryCollector.collect(argThat(equals(testUserId)), collectionCycleId: anyNamed('collectionCycleId'))).called(1);
      });

      test('should run location collection on first call', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        verify(mockLocationCollector.collect(argThat(equals(testUserId)), collectionCycleId: anyNamed('collectionCycleId'))).called(1);
      });

      test('should run sender on first call', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 5);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        verify(mockSender.sendAllData(testUserId, testEndpoint)).called(1);
      });

      test('should run cleanup on first call', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 10);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        verify(mockCleanupJob.cleanupAllData(testUserId)).called(1);
      });

      test('should handle battery collection error gracefully', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenThrow(Exception('Battery error'));
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        // Should not throw
        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        // Location should still run even if battery fails
        verify(mockLocationCollector.collect(argThat(equals(testUserId)), collectionCycleId: anyNamed('collectionCycleId'))).called(1);
      });

      test('should handle location collection error gracefully', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenThrow(Exception('Location error'));
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        // Should not throw
        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        // Sender should still run even if location fails
        verify(mockSender.sendAllData(testUserId, testEndpoint)).called(1);
      });

      test('should handle send error gracefully', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenThrow(Exception('Send error'));
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        // Should not throw
        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        // Cleanup should still run even if send fails
        verify(mockCleanupJob.cleanupAllData(testUserId)).called(1);
      });

      test('should handle cleanup error gracefully', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenThrow(Exception('Cleanup error'));
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        // Should not throw
        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        // Method should complete without error
        verify(mockCleanupJob.cleanupAllData(testUserId)).called(1);
      });

      test('should use location interval based on runner status', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: 'on_job',
          iotEndpoint: testEndpoint,
        );

        verify(mockConfig.getLocationInterval('on_job')).called(1);
      });

      test('should run device state collection on first call', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        verify(mockDeviceStateCollector.collect(argThat(equals(testUserId)), collectionCycleId: anyNamed('collectionCycleId'))).called(1);
      });

      test('should handle device state collection error gracefully', () async {
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenThrow(Exception('Device state error'));

        // Should not throw
        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        // Other jobs should still have run
        verify(mockBatteryCollector.collect(argThat(equals(testUserId)), collectionCycleId: anyNamed('collectionCycleId'))).called(1);
        verify(mockLocationCollector.collect(argThat(equals(testUserId)), collectionCycleId: anyNamed('collectionCycleId'))).called(1);
        verify(mockSender.sendAllData(testUserId, testEndpoint)).called(1);
        verify(mockCleanupJob.cleanupAllData(testUserId)).called(1);
      });

      test('should skip all jobs when previous cycle is still running', () async {
        // Use a completer to simulate a long-running job
        final completer = Completer<int>();
        when(mockBatteryCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => completer.future);
        when(mockLocationCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 0);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 0);
        when(mockDeviceStateCollector.collect(any, collectionCycleId: anyNamed('collectionCycleId'))).thenAnswer((_) async => 1);

        // Start the first call (it will block on battery collection)
        final firstCall = manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        // Allow the first call to start and set _isRunning = true
        await Future.microtask(() {});

        // Second call should be skipped (re-entrancy guard)
        await manager.runPeriodicJobs(
          userId: testUserId,
          runnerStatus: testRunnerStatus,
          iotEndpoint: testEndpoint,
        );

        // Complete the first call
        completer.complete(1);
        await firstCall;

        // Battery was called only once (by the first call), not twice
        verify(mockBatteryCollector.collect(argThat(equals(testUserId)), collectionCycleId: anyNamed('collectionCycleId'))).called(1);
      });
    });

    // ========================================================================
    // flush TESTS
    // ========================================================================

    group('flush', () {
      test('should return true when IoT is disabled', () async {
        when(mockConfig.apiEnabled).thenReturn(false);

        final result = await manager.flush(
          userId: testUserId,
          iotEndpoint: testEndpoint,
        );

        expect(result, true);
        verifyNever(mockSender.sendAllData(any, any));
        verifyNever(mockCleanupJob.cleanupAllData(any));
      });

      test('should send and cleanup when IoT is enabled', () async {
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 10);
        when(mockCleanupJob.cleanupAllData(any)).thenAnswer((_) async => 5);

        final result = await manager.flush(
          userId: testUserId,
          iotEndpoint: testEndpoint,
        );

        expect(result, true);
        verify(mockSender.sendAllData(testUserId, testEndpoint)).called(1);
        verify(mockCleanupJob.cleanupAllData(testUserId)).called(1);
      });

      test('should return false on send error', () async {
        when(mockSender.sendAllData(any, any)).thenThrow(Exception('Send failed'));

        final result = await manager.flush(
          userId: testUserId,
          iotEndpoint: testEndpoint,
        );

        expect(result, false);
      });

      test('should return false on cleanup error', () async {
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 10);
        when(mockCleanupJob.cleanupAllData(any)).thenThrow(Exception('Cleanup failed'));

        final result = await manager.flush(
          userId: testUserId,
          iotEndpoint: testEndpoint,
        );

        expect(result, false);
      });
    });

    // ========================================================================
    // flushAndDeleteAllUserData TESTS
    // ========================================================================

    group('flushAndDeleteAllUserData', () {
      test('should delete user data even when IoT is disabled', () async {
        when(mockConfig.apiEnabled).thenReturn(false);
        when(mockCleanupJob.deleteAllUserData(any)).thenAnswer((_) async => 50);

        final result = await manager.flushAndDeleteAllUserData(
          userId: testUserId,
          iotEndpoint: testEndpoint,
        );

        expect(result, true);
        verify(mockCleanupJob.deleteAllUserData(testUserId)).called(1);
        verifyNever(mockSender.sendAllData(any, any));
      });

      test('should send then delete when IoT is enabled', () async {
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 10);
        when(mockCleanupJob.deleteAllUserData(any)).thenAnswer((_) async => 100);

        final result = await manager.flushAndDeleteAllUserData(
          userId: testUserId,
          iotEndpoint: testEndpoint,
        );

        expect(result, true);
        verify(mockSender.sendAllData(testUserId, testEndpoint)).called(1);
        verify(mockCleanupJob.deleteAllUserData(testUserId)).called(1);
      });

      test('should still delete data even if send fails', () async {
        when(mockSender.sendAllData(any, any)).thenThrow(Exception('Send failed'));
        when(mockCleanupJob.deleteAllUserData(any)).thenAnswer((_) async => 50);

        final result = await manager.flushAndDeleteAllUserData(
          userId: testUserId,
          iotEndpoint: testEndpoint,
        );

        // Returns false because send failed, but data should still be deleted
        expect(result, false);
        verify(mockCleanupJob.deleteAllUserData(testUserId)).called(1);
      });

      test('should return false when both send and delete fail', () async {
        when(mockSender.sendAllData(any, any)).thenThrow(Exception('Send failed'));
        when(mockCleanupJob.deleteAllUserData(any)).thenThrow(Exception('Delete failed'));

        final result = await manager.flushAndDeleteAllUserData(
          userId: testUserId,
          iotEndpoint: testEndpoint,
        );

        expect(result, false);
      });

      test('should call deleteAllUserData not cleanupAllData', () async {
        when(mockSender.sendAllData(any, any)).thenAnswer((_) async => 10);
        when(mockCleanupJob.deleteAllUserData(any)).thenAnswer((_) async => 100);

        await manager.flushAndDeleteAllUserData(
          userId: testUserId,
          iotEndpoint: testEndpoint,
        );

        verify(mockCleanupJob.deleteAllUserData(testUserId)).called(1);
        verifyNever(mockCleanupJob.cleanupAllData(any));
      });
    });
  });
}

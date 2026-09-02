/**
 * Unit tests for BatteryCollector
 *
 * Purpose: Test battery data collection and storage
 * Related: SNCON-91 - IoT tracking system
 */

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/models/battery_data.dart';
import 'package:snabbit_runner/services/iot/collectors/battery_collector.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';

// Generate mocks
@GenerateMocks([IDatabaseInterface, Battery])
import 'battery_collector_test.mocks.dart';

void main() {
  group('BatteryCollector', () {
    late MockIDatabaseInterface mockDb;
    late MockBattery mockBattery;
    late BatteryCollector collector;
    const String testUserId = 'user-123';
    const int testCycleId = 1700000000000;

    setUp(() {
      mockDb = MockIDatabaseInterface();
      mockBattery = MockBattery();
      collector = BatteryCollector(
        database: mockDb,
        battery: mockBattery,
      );
    });

    group('collect', () {
      test('should collect battery level and store in database', () async {
        // Arrange
        const batteryLevel = 85;
        when(mockBattery.batteryLevel).thenAnswer((_) async => batteryLevel);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 1);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, 1);

        // Verify battery was queried
        verify(mockBattery.batteryLevel).called(1);

        // Verify insert was called with correct data
        final captured = verify(mockDb.insert(
          DatabaseTables.battery,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['user_id'], testUserId);
        expect(captured['percentage'], batteryLevel);
        expect(captured['sent'], false);
        expect(captured['collected_at'], isA<int>());
        expect(captured['collection_cycle_id'], testCycleId);
      });

      test('should handle different battery levels', () async {
        // Arrange
        const batteryLevel = 42;
        when(mockBattery.batteryLevel).thenAnswer((_) async => batteryLevel);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 2);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, 2);

        final captured = verify(mockDb.insert(
          DatabaseTables.battery,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['percentage'], batteryLevel);
      });

      test('should throw exception when battery query fails', () async {
        // Arrange
        when(mockBattery.batteryLevel).thenThrow(Exception('Battery unavailable'));

        // Act & Assert
        expect(
          () => collector.collect(testUserId, collectionCycleId: testCycleId),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when database insert fails', () async {
        // Arrange
        when(mockBattery.batteryLevel).thenAnswer((_) async => 85);
        when(mockDb.insert(any, any)).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => collector.collect(testUserId, collectionCycleId: testCycleId),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle 0% battery level', () async {
        // Arrange
        const batteryLevel = 0;
        when(mockBattery.batteryLevel).thenAnswer((_) async => batteryLevel);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 3);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, 3);

        final captured = verify(mockDb.insert(
          DatabaseTables.battery,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['percentage'], 0);
      });

      test('should handle 100% battery level', () async {
        // Arrange
        const batteryLevel = 100;
        when(mockBattery.batteryLevel).thenAnswer((_) async => batteryLevel);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 4);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, 4);

        final captured = verify(mockDb.insert(
          DatabaseTables.battery,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['percentage'], 100);
      });

      test('should store timestamp close to current time', () async {
        // Arrange
        when(mockBattery.batteryLevel).thenAnswer((_) async => 85);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 5);

        final beforeTime = DateTime.now().millisecondsSinceEpoch;

        // Act
        await collector.collect(testUserId, collectionCycleId: testCycleId);
        final afterTime = DateTime.now().millisecondsSinceEpoch;

        // Assert
        final captured = verify(mockDb.insert(
          DatabaseTables.battery,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        final collectedAt = captured['collected_at'] as int;
        expect(collectedAt, greaterThanOrEqualTo(beforeTime));
        expect(collectedAt, lessThanOrEqualTo(afterTime));
      });
    });

    group('getUnsentCount', () {
      test('should return count of unsent records for user', () async {
        // Arrange
        when(mockDb.count(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 5);

        // Act
        final count = await collector.getUnsentCount(testUserId);

        // Assert
        expect(count, 5);

        verify(mockDb.count(
          DatabaseTables.battery,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [testUserId, false],
        )).called(1);
      });

      test('should return 0 when no unsent records', () async {
        // Arrange
        when(mockDb.count(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);

        // Act
        final count = await collector.getUnsentCount(testUserId);

        // Assert
        expect(count, 0);
      });

      test('should filter by user ID', () async {
        // Arrange
        const differentUserId = 'user-456';
        when(mockDb.count(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 3);

        // Act
        await collector.getUnsentCount(differentUserId);

        // Assert
        verify(mockDb.count(
          DatabaseTables.battery,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [differentUserId, false],
        )).called(1);
      });
    });

    group('getUnsent', () {
      test('should return list of unsent battery records', () async {
        // Arrange
        final mockResults = [
          {
            'id': 1,
            'user_id': testUserId,
            'percentage': 85,
            'collected_at': DateTime.now().millisecondsSinceEpoch,
            'sent': false,
          },
          {
            'id': 2,
            'user_id': testUserId,
            'percentage': 84,
            'collected_at': DateTime.now().millisecondsSinceEpoch,
            'sent': false,
          },
        ];

        when(mockDb.query(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => mockResults);

        // Act
        final results = await collector.getUnsent(testUserId);

        // Assert
        expect(results.length, 2);
        expect(results[0], isA<BatteryData>());
        expect(results[0].userId, testUserId);
        expect(results[0].percentage, 85);
        expect(results[1].percentage, 84);

        verify(mockDb.query(
          DatabaseTables.battery,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [testUserId, false],
          orderBy: 'collected_at ASC',
          limit: null,
        )).called(1);
      });

      test('should return empty list when no unsent records', () async {
        // Arrange
        when(mockDb.query(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        // Act
        final results = await collector.getUnsent(testUserId);

        // Assert
        expect(results, isEmpty);
      });

      test('should respect limit parameter', () async {
        // Arrange
        final mockResults = [
          {
            'id': 1,
            'user_id': testUserId,
            'percentage': 85,
            'collected_at': DateTime.now().millisecondsSinceEpoch,
            'sent': false,
          },
        ];

        when(mockDb.query(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => mockResults);

        // Act
        final results = await collector.getUnsent(testUserId, limit: 10);

        // Assert
        expect(results.length, 1);

        verify(mockDb.query(
          DatabaseTables.battery,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [testUserId, false],
          orderBy: 'collected_at ASC',
          limit: 10,
        )).called(1);
      });

      test('should order by collected_at ASC (oldest first)', () async {
        // Arrange
        final time1 = DateTime.now().millisecondsSinceEpoch - 1000;
        final time2 = DateTime.now().millisecondsSinceEpoch;

        final mockResults = [
          {
            'id': 1,
            'user_id': testUserId,
            'percentage': 85,
            'collected_at': time1,
            'sent': false,
          },
          {
            'id': 2,
            'user_id': testUserId,
            'percentage': 84,
            'collected_at': time2,
            'sent': false,
          },
        ];

        when(mockDb.query(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => mockResults);

        // Act
        final results = await collector.getUnsent(testUserId);

        // Assert
        expect(results[0].collectedAt, time1);
        expect(results[1].collectedAt, time2);
        expect(results[0].collectedAt, lessThan(results[1].collectedAt));
      });

      test('should filter by user ID', () async {
        // Arrange
        const differentUserId = 'user-456';
        when(mockDb.query(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        // Act
        await collector.getUnsent(differentUserId);

        // Assert
        verify(mockDb.query(
          DatabaseTables.battery,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [differentUserId, false],
          orderBy: 'collected_at ASC',
          limit: null,
        )).called(1);
      });
    });
  });
}

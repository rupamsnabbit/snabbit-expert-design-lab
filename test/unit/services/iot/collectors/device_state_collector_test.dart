/**
 * Unit tests for DeviceStateCollector
 *
 * Purpose: Test device state data collection (location services, connectivity,
 * network type) and storage
 * Related: SNCON-91 - IoT tracking system
 */

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/models/device_state_data.dart';
import 'package:snabbit_runner/services/iot/collectors/device_state_collector.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';

// Generate mocks
@GenerateMocks([
  IDatabaseInterface,
  ILocationServiceChecker,
  IConnectivityChecker,
  INetworkTypeProvider,
])
import 'device_state_collector_test.mocks.dart';

void main() {
  group('DeviceStateCollector', () {
    late MockIDatabaseInterface mockDb;
    late MockILocationServiceChecker mockLocationServiceChecker;
    late MockIConnectivityChecker mockConnectivityChecker;
    late MockINetworkTypeProvider mockNetworkTypeProvider;
    late DeviceStateCollector collector;
    const String testUserId = 'user-123';
    const int testCycleId = 1700000000000;

    setUp(() {
      mockDb = MockIDatabaseInterface();
      mockLocationServiceChecker = MockILocationServiceChecker();
      mockConnectivityChecker = MockIConnectivityChecker();
      mockNetworkTypeProvider = MockINetworkTypeProvider();

      collector = DeviceStateCollector(
        database: mockDb,
        locationServiceChecker: mockLocationServiceChecker,
        connectivityChecker: mockConnectivityChecker,
        networkTypeProvider: mockNetworkTypeProvider,
      );
    });

    group('collect', () {
      test('should collect all 3 data sources and store in database', () async {
        // Arrange
        when(mockLocationServiceChecker.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockConnectivityChecker.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);
        when(mockNetworkTypeProvider.getNetworkType())
            .thenAnswer((_) async => '4g');
        when(mockDb.insert(any, any)).thenAnswer((_) async => 1);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, 1);

        // Verify all sources were queried
        verify(mockLocationServiceChecker.isLocationServiceEnabled()).called(1);
        verify(mockConnectivityChecker.checkConnectivity()).called(1);
        verify(mockNetworkTypeProvider.getNetworkType()).called(1);

        // Verify insert was called with correct data
        final captured = verify(mockDb.insert(
          DatabaseTables.deviceState,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['user_id'], testUserId);
        expect(captured['location_services_on'], true);
        expect(captured['mobile_data_on'], true);
        expect(captured['network_type'], '4g');
        expect(captured['sent'], false);
        expect(captured['collected_at'], isA<int>());
        expect(captured['collection_cycle_id'], testCycleId);
      });

      test('should set networkType to "wifi" when WiFi detected (skip platform channel)', () async {
        // Arrange
        when(mockLocationServiceChecker.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockConnectivityChecker.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 2);

        // Act
        await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert: platform channel NOT called when WiFi
        verifyNever(mockNetworkTypeProvider.getNetworkType());

        final captured = verify(mockDb.insert(
          DatabaseTables.deviceState,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['network_type'], 'wifi');
        // WiFi detected: mobileDataOn should be false (no mobile result in list)
        expect(captured['mobile_data_on'], false);
      });

      test('should prefer "wifi" when both WiFi and mobile connected (dual-stack)', () async {
        // Arrange
        when(mockLocationServiceChecker.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockConnectivityChecker.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi, ConnectivityResult.mobile]);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 11);

        // Act
        await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert: platform channel NOT called (WiFi takes precedence)
        verifyNever(mockNetworkTypeProvider.getNetworkType());

        final captured = verify(mockDb.insert(
          DatabaseTables.deviceState,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['network_type'], 'wifi');
        expect(captured['mobile_data_on'], true);
      });

      test('should set networkType to "none" when no connectivity', () async {
        // Arrange
        when(mockLocationServiceChecker.isLocationServiceEnabled())
            .thenAnswer((_) async => false);
        when(mockConnectivityChecker.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 3);

        // Act
        await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert: platform channel NOT called when no connectivity
        verifyNever(mockNetworkTypeProvider.getNetworkType());

        final captured = verify(mockDb.insert(
          DatabaseTables.deviceState,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['network_type'], 'none');
        expect(captured['mobile_data_on'], false);
      });

      test('should set locationServicesOn to null when geolocator throws', () async {
        // Arrange
        when(mockLocationServiceChecker.isLocationServiceEnabled())
            .thenThrow(Exception('Location service unavailable'));
        when(mockConnectivityChecker.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);
        when(mockNetworkTypeProvider.getNetworkType())
            .thenAnswer((_) async => '4g');
        when(mockDb.insert(any, any)).thenAnswer((_) async => 4);

        // Act
        await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        final captured = verify(mockDb.insert(
          DatabaseTables.deviceState,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['location_services_on'], isNull);
        // Other sources should still have values
        expect(captured['mobile_data_on'], true);
        expect(captured['network_type'], '4g');
      });

      test('should set mobileDataOn and networkType to null when connectivity throws', () async {
        // Arrange
        when(mockLocationServiceChecker.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockConnectivityChecker.checkConnectivity())
            .thenThrow(Exception('Connectivity check failed'));
        when(mockDb.insert(any, any)).thenAnswer((_) async => 5);

        // Act
        await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        final captured = verify(mockDb.insert(
          DatabaseTables.deviceState,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['mobile_data_on'], isNull);
        expect(captured['network_type'], isNull);
        // Other sources should still have values
        expect(captured['location_services_on'], true);
      });

      test('should still insert record when all sources fail (all nulls)', () async {
        // Arrange: all mocks throw
        when(mockLocationServiceChecker.isLocationServiceEnabled())
            .thenThrow(Exception('Location failed'));
        when(mockConnectivityChecker.checkConnectivity())
            .thenThrow(Exception('Connectivity failed'));
        when(mockDb.insert(any, any)).thenAnswer((_) async => 7);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert: db.insert still called
        expect(id, 7);

        final captured = verify(mockDb.insert(
          DatabaseTables.deviceState,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['user_id'], testUserId);
        expect(captured['location_services_on'], isNull);
        expect(captured['mobile_data_on'], isNull);
        expect(captured['network_type'], isNull);
        expect(captured['sent'], false);
        expect(captured['collected_at'], isA<int>());
      });

      test('should store timestamp close to current time', () async {
        // Arrange
        when(mockLocationServiceChecker.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockConnectivityChecker.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);
        when(mockNetworkTypeProvider.getNetworkType())
            .thenAnswer((_) async => '4g');
        when(mockDb.insert(any, any)).thenAnswer((_) async => 10);

        final beforeTime = DateTime.now().millisecondsSinceEpoch;

        // Act
        await collector.collect(testUserId, collectionCycleId: testCycleId);

        final afterTime = DateTime.now().millisecondsSinceEpoch;

        // Assert
        final captured = verify(mockDb.insert(
          DatabaseTables.deviceState,
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
          DatabaseTables.deviceState,
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
          DatabaseTables.deviceState,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [differentUserId, false],
        )).called(1);
      });
    });

    group('getUnsent', () {
      test('should return list of unsent device state records', () async {
        // Arrange
        final now = DateTime.now().millisecondsSinceEpoch;
        final mockResults = [
          {
            'id': 1,
            'user_id': testUserId,
            'location_services_on': true,
            'mobile_data_on': true,
            'network_type': '4g',
            'collected_at': now - 1000,
            'sent': false,
          },
          {
            'id': 2,
            'user_id': testUserId,
            'location_services_on': false,
            'mobile_data_on': false,
            'network_type': 'none',
            'collected_at': now,
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
        expect(results[0], isA<DeviceStateData>());
        expect(results[0].userId, testUserId);
        expect(results[0].locationServicesOn, true);
        expect(results[0].mobileDataOn, true);
        expect(results[0].networkType, '4g');
        expect(results[1].networkType, 'none');

        verify(mockDb.query(
          DatabaseTables.deviceState,
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
            'location_services_on': true,
            'mobile_data_on': true,
            'network_type': 'wifi',
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
          DatabaseTables.deviceState,
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
            'location_services_on': true,
            'mobile_data_on': true,
            'network_type': '4g',
            'collected_at': time1,
            'sent': false,
          },
          {
            'id': 2,
            'user_id': testUserId,
            'location_services_on': true,
            'mobile_data_on': true,
            'network_type': '4g',
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
          DatabaseTables.deviceState,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [differentUserId, false],
          orderBy: 'collected_at ASC',
          limit: null,
        )).called(1);
      });
    });
  });
}

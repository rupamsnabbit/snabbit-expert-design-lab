/**
 * Unit tests for LocationCollector
 *
 * Purpose: Test GPS location data collection and storage
 * Related: SNCON-91 - IoT tracking system
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/models/location_data.dart';
import 'package:snabbit_runner/services/iot/collectors/device_state_collector.dart';
import 'package:snabbit_runner/services/iot/collectors/location_collector.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';

// Generate mocks
@GenerateMocks([IDatabaseInterface, ILocationProvider, ILocationServiceChecker])
import 'location_collector_test.mocks.dart';

/// Minimal permission checker stub so tests can deterministically pass the
/// permission gate and exercise the location-services-off path.
class _AlwaysGrantedPermissionChecker implements ILocationPermissionChecker {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;
}

void main() {
  group('LocationCollector', () {
    late MockIDatabaseInterface mockDb;
    late MockILocationProvider mockLocationProvider;
    late MockILocationServiceChecker mockLocationServiceChecker;
    late LocationCollector collector;
    const String testUserId = 'user-123';
    const int testCycleId = 1700000000000;

    setUp(() {
      mockDb = MockIDatabaseInterface();
      mockLocationProvider = MockILocationProvider();
      mockLocationServiceChecker = MockILocationServiceChecker();
      // Default: location services enabled
      when(mockLocationServiceChecker.isLocationServiceEnabled())
          .thenAnswer((_) async => true);
      collector = LocationCollector(
        database: mockDb,
        locationProvider: mockLocationProvider,
        locationServiceChecker: mockLocationServiceChecker,
      );
    });

    /// Helper to create a Position object for testing
    Position createMockPosition({
      double latitude = 19.076,
      double longitude = 72.8777,
      double accuracy = 12.5,
      double altitude = 45.0,
      double altitudeAccuracy = 8.0,
      double heading = 180.0,
      double headingAccuracy = 5.0,
      double speed = 15.5,
      double speedAccuracy = 0.8,
      bool isMocked = false,
    }) {
      return Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: accuracy,
        altitude: altitude,
        altitudeAccuracy: altitudeAccuracy,
        heading: heading,
        headingAccuracy: headingAccuracy,
        speed: speed,
        speedAccuracy: speedAccuracy,
        isMocked: isMocked,
      );
    }

    group('collect', () {
      test('should collect location data and store in database', () async {
        // Arrange
        final mockPosition = createMockPosition();

        when(mockLocationProvider.getCurrentPosition())
            .thenAnswer((_) async => mockPosition);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 1);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, 1);

        // Verify location was queried
        verify(mockLocationProvider.getCurrentPosition()).called(1);

        // Verify insert was called with correct data
        final captured = verify(mockDb.insert(
          DatabaseTables.location,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['user_id'], testUserId);
        expect(captured['lat'], 19.076);
        expect(captured['long'], 72.8777);
        expect(captured['accuracy'], 12.5);
        expect(captured['alt'], 45.0);
        expect(captured['alt_accuracy'], 8.0);
        expect(captured['heading'], 180.0);
        expect(captured['heading_accuracy'], 5.0);
        expect(captured['speed'], 15.5);
        expect(captured['speed_accuracy'], 0.8);
        expect(captured['is_mocked'], false);
        expect(captured['sent'], false);
        expect(captured['collected_at'], isA<int>());
        expect(captured['collection_cycle_id'], testCycleId);
      });

      test('should handle mocked location', () async {
        // Arrange
        final mockPosition = createMockPosition(isMocked: true);

        when(mockLocationProvider.getCurrentPosition())
            .thenAnswer((_) async => mockPosition);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 3);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, 3);

        final captured = verify(mockDb.insert(
          DatabaseTables.location,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['is_mocked'], true);
      });

      test('should return service-disabled code (-4) when location services are off',
          () async {
        // Arrange: permission granted so we reach the service check, which is off.
        collector = LocationCollector(
          database: mockDb,
          locationProvider: mockLocationProvider,
          locationServiceChecker: mockLocationServiceChecker,
          permissionChecker: _AlwaysGrantedPermissionChecker(),
        );
        when(mockLocationServiceChecker.isLocationServiceEnabled())
            .thenAnswer((_) async => false);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, -4);
        verifyNever(mockLocationProvider.getCurrentPosition());
        verifyNever(mockDb.insert(any, any));
      });

      test('should throw exception when location query fails', () async {
        // Arrange
        when(mockLocationProvider.getCurrentPosition())
            .thenThrow(Exception('Location unavailable'));

        // Act & Assert
        expect(
          () => collector.collect(testUserId, collectionCycleId: testCycleId),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw exception when database insert fails', () async {
        // Arrange
        final mockPosition = createMockPosition();

        when(mockLocationProvider.getCurrentPosition())
            .thenAnswer((_) async => mockPosition);
        when(mockDb.insert(any, any)).thenThrow(Exception('Database error'));

        // Act & Assert
        expect(
          () => collector.collect(testUserId, collectionCycleId: testCycleId),
          throwsA(isA<Exception>()),
        );
      });

      test('should store timestamp close to current time', () async {
        // Arrange
        final mockPosition = createMockPosition();

        when(mockLocationProvider.getCurrentPosition())
            .thenAnswer((_) async => mockPosition);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 5);

        final beforeTime = DateTime.now().millisecondsSinceEpoch;

        // Act
        await collector.collect(testUserId, collectionCycleId: testCycleId);
        final afterTime = DateTime.now().millisecondsSinceEpoch;

        // Assert
        final captured = verify(mockDb.insert(
          DatabaseTables.location,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        final collectedAt = captured['collected_at'] as int;
        expect(collectedAt, greaterThanOrEqualTo(beforeTime));
        expect(collectedAt, lessThanOrEqualTo(afterTime));
      });

      test('should handle negative coordinates', () async {
        // Arrange
        final mockPosition = createMockPosition(
          latitude: -33.8688,
          longitude: 151.2093,
        );

        when(mockLocationProvider.getCurrentPosition())
            .thenAnswer((_) async => mockPosition);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 6);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, 6);

        final captured = verify(mockDb.insert(
          DatabaseTables.location,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['lat'], -33.8688);
        expect(captured['long'], 151.2093);
      });

      test('should handle high accuracy values', () async {
        // Arrange
        final mockPosition = createMockPosition(accuracy: 1500.0);

        when(mockLocationProvider.getCurrentPosition())
            .thenAnswer((_) async => mockPosition);
        when(mockDb.insert(any, any)).thenAnswer((_) async => 7);

        // Act
        final id = await collector.collect(testUserId, collectionCycleId: testCycleId);

        // Assert
        expect(id, 7);

        final captured = verify(mockDb.insert(
          DatabaseTables.location,
          captureAny,
        )).captured.single as Map<String, dynamic>;

        expect(captured['accuracy'], 1500.0);
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
          DatabaseTables.location,
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
          DatabaseTables.location,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [differentUserId, false],
        )).called(1);
      });
    });

    group('getUnsent', () {
      test('should return list of unsent location records', () async {
        // Arrange
        final mockResults = [
          {
            'id': 1,
            'user_id': testUserId,
            'lat': 19.076,
            'long': 72.8777,
            'accuracy': 12.5,
            'alt': 45.0,
            'alt_accuracy': 8.0,
            'heading': 180.0,
            'heading_accuracy': 5.0,
            'speed': 15.5,
            'speed_accuracy': 0.8,
            'is_mocked': false,
            'collected_at': DateTime.now().millisecondsSinceEpoch,
            'sent': false,
          },
          {
            'id': 2,
            'user_id': testUserId,
            'lat': 19.077,
            'long': 72.8778,
            'accuracy': 10.0,
            'alt': 46.0,
            'alt_accuracy': 7.0,
            'heading': 185.0,
            'heading_accuracy': 4.0,
            'speed': 16.0,
            'speed_accuracy': 0.9,
            'is_mocked': false,
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
        expect(results[0], isA<LocationData>());
        expect(results[0].userId, testUserId);
        expect(results[0].lat, 19.076);
        expect(results[0].long, 72.8777);
        expect(results[1].lat, 19.077);
        expect(results[1].long, 72.8778);

        verify(mockDb.query(
          DatabaseTables.location,
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
            'lat': 19.076,
            'long': 72.8777,
            'accuracy': 12.5,
            'is_mocked': false,
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
          DatabaseTables.location,
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
            'lat': 19.076,
            'long': 72.8777,
            'accuracy': 12.5,
            'is_mocked': false,
            'collected_at': time1,
            'sent': false,
          },
          {
            'id': 2,
            'user_id': testUserId,
            'lat': 19.077,
            'long': 72.8778,
            'accuracy': 10.0,
            'is_mocked': false,
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
          DatabaseTables.location,
          where: 'user_id = ? AND sent = ?',
          whereArgs: [differentUserId, false],
          orderBy: 'collected_at ASC',
          limit: null,
        )).called(1);
      });
    });
  });
}

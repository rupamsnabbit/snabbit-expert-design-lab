/**
 * Unit tests for Sender
 *
 * Purpose: Test IoT data sending and deletion (post-send cleanup) to backend
 * Related: SNCON-91 - IoT tracking system
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/models/battery_data.dart';
import 'package:snabbit_runner/models/device_state_data.dart';
import 'package:snabbit_runner/models/location_data.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/iot/collectors/battery_collector.dart';
import 'package:snabbit_runner/services/iot/collectors/device_state_collector.dart';
import 'package:snabbit_runner/services/iot/collectors/location_collector.dart';
import 'package:snabbit_runner/services/iot/http/iot_http.dart';
import 'package:snabbit_runner/services/iot/sender/sender.dart';

// Generate mocks for dependencies
@GenerateMocks([
  IDatabaseInterface,
  BatteryCollector,
  LocationCollector,
  DeviceStateCollector,
  IotHttp,
])
import 'sender_test.mocks.dart';

void main() {
  group('Sender', () {
    late MockIDatabaseInterface mockDb;
    late MockBatteryCollector mockBatteryCollector;
    late MockLocationCollector mockLocationCollector;
    late MockDeviceStateCollector mockDeviceStateCollector;
    late MockIotHttp mockIotHttp;
    late Sender sender;

    const String testUserId = 'user-123';
    const String iotEndpoint = 'https://api.example.com/iot';

    setUp(() {
      mockDb = MockIDatabaseInterface();
      mockBatteryCollector = MockBatteryCollector();
      mockLocationCollector = MockLocationCollector();
      mockDeviceStateCollector = MockDeviceStateCollector();
      mockIotHttp = MockIotHttp();

      sender = Sender(
        database: mockDb,
        batteryCollector: mockBatteryCollector,
        locationCollector: mockLocationCollector,
        deviceStateCollector: mockDeviceStateCollector,
        iotHttp: mockIotHttp,
      );
    });

    group('sendAllData', () {
      test('should send battery and location data and delete on success', () async {
        // Arrange: Create mock unsent battery and location records
        final unsentBatteries = [
          BatteryData(
            id: 1,
            userId: testUserId,
            percentage: 85,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
          BatteryData(
            id: 2,
            userId: testUserId,
            percentage: 80,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        final unsentLocations = [
          LocationData(
            id: 1,
            userId: testUserId,
            lat: 19.0760,
            long: 72.8777,
            accuracy: 10.5,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => unsentBatteries);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => unsentLocations);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 2);

        // Act: Call sendAllData
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify correct number returned (batteries + locations)
        expect(result, 3);

        // Verify getUnsent was called for all three
        verify(mockBatteryCollector.getUnsent(testUserId)).called(1);
        verify(mockLocationCollector.getUnsent(testUserId)).called(1);
        verify(mockDeviceStateCollector.getUnsent(testUserId)).called(1);

        // Verify sendIotData was called with correct parameters
        verify(mockIotHttp.sendIotData(
          endpoint: iotEndpoint,
          userId: testUserId,
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).called(1);

        // Verify db.delete was called for both tables (post-send cleanup)
        verify(mockDb.delete(
          DatabaseTables.battery,
          where: 'id IN (?,?)',
          whereArgs: [1, 2],
        )).called(1);
        verify(mockDb.delete(
          DatabaseTables.location,
          where: 'id IN (?)',
          whereArgs: [1],
        )).called(1);
      });

      test('should return 0 when no unsent records', () async {
        // Arrange: Mock collectors to return empty lists
        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);

        // Act: Call sendAllData
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify returns 0
        expect(result, 0);

        // Verify getUnsent was called
        verify(mockBatteryCollector.getUnsent(testUserId)).called(1);
        verify(mockLocationCollector.getUnsent(testUserId)).called(1);
        verify(mockDeviceStateCollector.getUnsent(testUserId)).called(1);

        // Verify sendIotData was NOT called
        verifyNever(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        ));

        // Verify db.delete was NOT called
        verifyNever(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')));
      });

      test('should not delete when API returns failure', () async {
        // Arrange: Create mock unsent records
        final unsentBatteries = [
          BatteryData(
            id: 1,
            userId: testUserId,
            percentage: 85,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => unsentBatteries);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => false);

        // Act: Call sendAllData
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify returns 0
        expect(result, 0);

        // Verify sendIotData was called
        verify(mockIotHttp.sendIotData(
          endpoint: iotEndpoint,
          userId: testUserId,
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).called(1);

        // Verify db.delete was NOT called (records remain for retry)
        verifyNever(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')));
      });

      test('should handle exception and return 0', () async {
        // Arrange: Mock batteryCollector.getUnsent to throw exception
        when(mockBatteryCollector.getUnsent(any))
            .thenThrow(Exception('Database error'));

        // Act: Call sendAllData
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify returns 0 (doesn't throw)
        expect(result, 0);

        // Verify graceful error handling
        verify(mockBatteryCollector.getUnsent(testUserId)).called(1);
      });

      test('should send only battery data when no location records', () async {
        // Arrange
        final unsentBatteries = [
          BatteryData(
            id: 1,
            userId: testUserId,
            percentage: 85,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
          BatteryData(
            id: 2,
            userId: testUserId,
            percentage: 80,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => unsentBatteries);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 2);

        // Act
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert
        expect(result, 2);
        verify(mockDb.delete(
          DatabaseTables.battery,
          where: 'id IN (?,?)',
          whereArgs: [1, 2],
        )).called(1);
      });

      test('should send only location data when no battery records', () async {
        // Arrange
        final unsentLocations = [
          LocationData(
            id: 1,
            userId: testUserId,
            lat: 19.0760,
            long: 72.8777,
            accuracy: 10.5,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
          LocationData(
            id: 2,
            userId: testUserId,
            lat: 19.0761,
            long: 72.8778,
            accuracy: 12.3,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => unsentLocations);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 2);

        // Act
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert
        expect(result, 2);
        verify(mockDb.delete(
          DatabaseTables.location,
          where: 'id IN (?,?)',
          whereArgs: [1, 2],
        )).called(1);
      });

      test('should handle multiple battery and location records', () async {
        // Arrange: Create multiple records
        final unsentBatteries = List.generate(3, (i) => BatteryData(
          id: i + 1,
          userId: testUserId,
          percentage: 85 - i,
          collectedAt: DateTime.now().millisecondsSinceEpoch,
          sent: false,
        ));

        final unsentLocations = List.generate(5, (i) => LocationData(
          id: i + 1,
          userId: testUserId,
          lat: 19.0760 + i * 0.001,
          long: 72.8777 + i * 0.001,
          accuracy: 10.5,
          collectedAt: DateTime.now().millisecondsSinceEpoch,
          sent: false,
        ));

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => unsentBatteries);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => unsentLocations);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 3);

        // Act
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify returns total count (3 + 5 = 8)
        expect(result, 8);

        // Verify all battery IDs included in delete
        verify(mockDb.delete(
          DatabaseTables.battery,
          where: 'id IN (?,?,?)',
          whereArgs: [1, 2, 3],
        )).called(1);

        // Verify all location IDs included in delete
        verify(mockDb.delete(
          DatabaseTables.location,
          where: 'id IN (?,?,?,?,?)',
          whereArgs: [1, 2, 3, 4, 5],
        )).called(1);
      });

      test('should handle records without IDs', () async {
        // Arrange: Create records with some null IDs
        final unsentBatteries = [
          BatteryData(
            id: 1,
            userId: testUserId,
            percentage: 85,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
          BatteryData(
            id: 0,  // 0 indicates unsaved record
            userId: testUserId,
            percentage: 80,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
          BatteryData(
            id: 3,
            userId: testUserId,
            percentage: 75,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => unsentBatteries);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 2);

        // Act
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify returns total count
        expect(result, 3);

        // Verify only records with IDs are included in delete
        verify(mockDb.delete(
          DatabaseTables.battery,
          where: 'id IN (?,?)',
          whereArgs: [1, 3],
        )).called(1);
      });

      test('should pass correct userId and endpoint to IotHttp', () async {
        // Arrange
        final unsentBatteries = [
          BatteryData(
            id: 1,
            userId: testUserId,
            percentage: 85,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => unsentBatteries);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);

        // Act
        await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify IotHttp was called with correct parameters
        verify(mockIotHttp.sendIotData(
          endpoint: iotEndpoint,
          userId: testUserId,
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).called(1);
      });

      test('should convert records to maps before sending', () async {
        // Arrange
        final unsentBatteries = [
          BatteryData(
            id: 1,
            userId: testUserId,
            percentage: 85,
            collectedAt: 1234567890,
            sent: false,
          ),
        ];

        final unsentLocations = [
          LocationData(
            id: 1,
            userId: testUserId,
            lat: 19.0760,
            long: 72.8777,
            accuracy: 10.5,
            collectedAt: 1234567890,
            sent: false,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => unsentBatteries);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => unsentLocations);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);

        // Act
        await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify sendIotData was called with list of maps
        final captured = verify(mockIotHttp.sendIotData(
          endpoint: iotEndpoint,
          userId: testUserId,
          batteries: captureAnyNamed('batteries'),
          locations: captureAnyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).captured;

        final capturedBatteries = captured[0] as List<Map<String, dynamic>>;
        expect(capturedBatteries.length, 1);
        expect(capturedBatteries[0]['percentage'], 85);
        expect(capturedBatteries[0]['collected_at'], 1234567890);

        final capturedLocations = captured[1] as List<Map<String, dynamic>>;
        expect(capturedLocations.length, 1);
        expect(capturedLocations[0]['lat'], 19.0760);
        expect(capturedLocations[0]['long'], 72.8777);
      });

      test('should use correct database tables for deletes', () async {
        // Arrange
        final unsentBatteries = [
          BatteryData(
            id: 1,
            userId: testUserId,
            percentage: 85,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        final unsentLocations = [
          LocationData(
            id: 1,
            userId: testUserId,
            lat: 19.0760,
            long: 72.8777,
            accuracy: 10.5,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => unsentBatteries);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => unsentLocations);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);

        // Act
        await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify correct tables used
        verify(mockDb.delete(
          DatabaseTables.battery,
          where: 'id IN (?)',
          whereArgs: [1],
        )).called(1);

        verify(mockDb.delete(
          DatabaseTables.location,
          where: 'id IN (?)',
          whereArgs: [1],
        )).called(1);
      });

      test('should include device state records in send count', () async {
        // Arrange
        final unsentBatteries = [
          BatteryData(
            id: 1,
            userId: testUserId,
            percentage: 85,
            collectedAt: DateTime.now().millisecondsSinceEpoch,
            sent: false,
          ),
        ];

        final unsentDeviceStates = [
          DeviceStateData(
            id: 1,
            userId: testUserId,
            locationServicesOn: true,
            mobileDataOn: true,
            networkType: '4g',
            collectedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          DeviceStateData(
            id: 2,
            userId: testUserId,
            locationServicesOn: false,
            mobileDataOn: false,
            networkType: 'none',
            collectedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => unsentBatteries);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => unsentDeviceStates);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);

        // Act
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: 1 battery + 2 device states = 3
        expect(result, 3);
      });

      test('should delete device state records on successful send', () async {
        // Arrange
        final unsentDeviceStates = [
          DeviceStateData(
            id: 1,
            userId: testUserId,
            locationServicesOn: true,
            mobileDataOn: true,
            networkType: '4g',
            collectedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          DeviceStateData(
            id: 2,
            userId: testUserId,
            locationServicesOn: false,
            mobileDataOn: false,
            networkType: 'none',
            collectedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => unsentDeviceStates);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 2);

        // Act
        await sender.sendAllData(testUserId, iotEndpoint);

        // Assert: Verify device state records were deleted
        verify(mockDb.delete(
          DatabaseTables.deviceState,
          where: 'id IN (?,?)',
          whereArgs: [1, 2],
        )).called(1);
      });

      test('three-way empty check returns 0 when battery, location, and device state all empty', () async {
        // Arrange
        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => []);

        // Act
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert
        expect(result, 0);

        // Verify send was never called
        verifyNever(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        ));
      });

      test('should send only device state data when no battery/location records', () async {
        // Arrange
        final unsentDeviceStates = [
          DeviceStateData(
            id: 1,
            userId: testUserId,
            locationServicesOn: true,
            mobileDataOn: true,
            networkType: 'wifi',
            collectedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ];

        when(mockBatteryCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockLocationCollector.getUnsent(any))
            .thenAnswer((_) async => []);
        when(mockDeviceStateCollector.getUnsent(any))
            .thenAnswer((_) async => unsentDeviceStates);
        when(mockIotHttp.sendIotData(
          endpoint: anyNamed('endpoint'),
          userId: anyNamed('userId'),
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).thenAnswer((_) async => true);
        when(mockDb.delete(any, where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);

        // Act
        final result = await sender.sendAllData(testUserId, iotEndpoint);

        // Assert
        expect(result, 1);

        // Verify sendIotData was called
        verify(mockIotHttp.sendIotData(
          endpoint: iotEndpoint,
          userId: testUserId,
          batteries: anyNamed('batteries'),
          locations: anyNamed('locations'),
          deviceStates: anyNamed('deviceStates'),
        )).called(1);

        // Verify device state was deleted
        verify(mockDb.delete(
          DatabaseTables.deviceState,
          where: 'id IN (?)',
          whereArgs: [1],
        )).called(1);

        // Verify no battery or location deletes
        verifyNever(mockDb.delete(
          DatabaseTables.battery,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ));
        verifyNever(mockDb.delete(
          DatabaseTables.location,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ));
      });
    });
  });
}

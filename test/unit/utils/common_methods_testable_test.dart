/**
 * Unit tests for CommonMethodsTestable.fetchCurrentLocation()
 *
 * Purpose: Regression testing for fetchCurrentLocation logic before SNCON-91
 * Related: SNCON-92 - Regression tests before enhanced location tracking
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/utils/common_methods_testable.dart';

// Reuse the mock from runner_http_testable_test
import '../services/runner_http_testable_test.mocks.dart';

void main() {
  group('CommonMethodsTestable.fetchCurrentLocation', () {
    late MockIGeolocatorWrapper mockGeolocator;
    late CommonMethodsTestable commonMethods;

    setUp(() {
      mockGeolocator = MockIGeolocatorWrapper();
      commonMethods = CommonMethodsTestable(geolocator: mockGeolocator);
    });

    group('Happy Path', () {
      test('should return position when location services enabled and permission granted', () async {
        // Arrange
        final expectedPosition = Position(
          latitude: 19.0760,
          longitude: 72.8777,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 14.5,
          heading: 90.0,
          speed: 12.5,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        when(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        )).thenAnswer((_) async => expectedPosition);

        // Act
        final result = await commonMethods.fetchCurrentLocation();

        // Assert
        expect(result, isNotNull);
        expect(result?.latitude, 19.0760);
        expect(result?.longitude, 72.8777);
        expect(result?.accuracy, 5.0);

        verify(mockGeolocator.isLocationServiceEnabled()).called(1);
        verify(mockGeolocator.checkPermission()).called(1);
        verify(mockGeolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 5),
        )).called(1);
      });

      test('should work with LocationPermission.always', () async {
        // Arrange
        final expectedPosition = Position(
          latitude: 18.0,
          longitude: 73.0,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.always);
        when(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        )).thenAnswer((_) async => expectedPosition);

        // Act
        final result = await commonMethods.fetchCurrentLocation();

        // Assert
        expect(result, isNotNull);
        expect(result?.latitude, 18.0);
      });
    });

    group('Edge Cases - Location Service Disabled', () {
      test('should return null when location services disabled', () async {
        // Arrange
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => false);

        // Act
        final result = await commonMethods.fetchCurrentLocation();

        // Assert
        expect(result, isNull);

        verify(mockGeolocator.isLocationServiceEnabled()).called(1);
        verifyNever(mockGeolocator.checkPermission());
        verifyNever(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        ));
      });
    });

    group('Edge Cases - Permission Denied', () {
      test('should return null when permission is denied', () async {
        // Arrange
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.denied);

        // Act
        final result = await commonMethods.fetchCurrentLocation();

        // Assert
        expect(result, isNull);

        verify(mockGeolocator.isLocationServiceEnabled()).called(1);
        verify(mockGeolocator.checkPermission()).called(1);
        verifyNever(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        ));
      });

      test('should return null when permission is deniedForever', () async {
        // Arrange
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.deniedForever);

        // Act
        final result = await commonMethods.fetchCurrentLocation();

        // Assert
        expect(result, isNull);
        verifyNever(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        ));
      });
    });

    group('Error Handling', () {
      test('should return null when getCurrentPosition throws exception', () async {
        // Arrange
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        when(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        )).thenThrow(Exception('GPS timeout'));

        // Act
        final result = await commonMethods.fetchCurrentLocation();

        // Assert
        expect(result, isNull);
      });

      test('should return null when isLocationServiceEnabled throws exception', () async {
        // Arrange
        when(mockGeolocator.isLocationServiceEnabled())
            .thenThrow(Exception('Service check failed'));

        // Act
        final result = await commonMethods.fetchCurrentLocation();

        // Assert
        expect(result, isNull);
      });

      test('should return null when checkPermission throws exception', () async {
        // Arrange
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenThrow(Exception('Permission check failed'));

        // Act
        final result = await commonMethods.fetchCurrentLocation();

        // Assert
        expect(result, isNull);
      });
    });
  });
}

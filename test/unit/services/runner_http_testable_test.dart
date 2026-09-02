/**
 * Unit tests for RunnerHttpTestable
 *
 * Purpose: Regression testing for runnerAppCurrentState logic
 * Approach: Use wrapper interfaces to mock static dependencies
 *
 * This demonstrates how to unit test static method logic without refactoring to full DI
 */

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/services/runner_http_testable.dart';
import 'package:snabbit_runner/services/runner_http_wrapper.dart';

// Generate mocks
@GenerateMocks([
  IHttpServiceWrapper,
  IGlobalStateWrapper,
  IGeolocatorWrapper,
  IBatteryWrapper,
])
import 'runner_http_testable_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider for FileStorage
  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return '/tmp';
    }
    return null;
  });
  group('RunnerHttpTestable.runnerAppCurrentState', () {
    late MockIHttpServiceWrapper mockHttp;
    late MockIGlobalStateWrapper mockGlobalState;
    late MockIGeolocatorWrapper mockGeolocator;
    late MockIBatteryWrapper mockBattery;
    late RunnerHttpTestable runnerHttp;

    setUp(() {
      mockHttp = MockIHttpServiceWrapper();
      mockGlobalState = MockIGlobalStateWrapper();
      mockGeolocator = MockIGeolocatorWrapper();
      mockBattery = MockIBatteryWrapper();

      runnerHttp = RunnerHttpTestable(
        httpService: mockHttp,
        globalState: mockGlobalState,
        geolocator: mockGeolocator,
        battery: mockBattery,
      );
    });

    group('Happy Path - Location services enabled with permission', () {
      test('should fetch location and make API call with lat/lng/battery params',
          () async {
        // Arrange
        const expectedBattery = '85%';
        const expectedLat = 19.0760;
        const expectedLng = 72.8777;
        const expectedUrl =
            'https://api.test/api/v1/runners/me/app/current_state?lat=$expectedLat&lng=$expectedLng&battery=$expectedBattery&is_fg=true';

        final mockPosition = Position(
          latitude: expectedLat,
          longitude: expectedLng,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        final mockResponse = Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {'status': 'success'},
        );

        when(mockBattery.getBatteryLevel())
            .thenAnswer((_) async => expectedBattery);
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        when(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        )).thenAnswer((_) async => mockPosition);
        when(mockGlobalState.serverPath(any)).thenReturn(expectedUrl);
        when(mockHttp.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await runnerHttp.runnerAppCurrentState();

        // Assert
        expect(result, isNotNull);
        expect(result?.statusCode, 200);
        expect(result?.data, {'status': 'success'});

        // Verify correct URL was called with lat/lng/battery
        verify(mockGlobalState.serverPath(
          'api/v1/runners/me/app/current_state?lat=$expectedLat&lng=$expectedLng&battery=$expectedBattery&is_fg=true',
        )).called(1);

        verify(mockHttp.get(expectedUrl, headers: {})).called(1);
        verify(mockBattery.getBatteryLevel()).called(1);
        verify(mockGeolocator.isLocationServiceEnabled()).called(1);
        verify(mockGeolocator.checkPermission()).called(1);
        verify(mockGeolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 45),
        )).called(1);
      });

      test('should pass custom headers to HTTP service', () async {
        // Arrange
        final customHeaders = {'Authorization': 'Bearer token123'};
        final mockPosition = Position(
          latitude: 19.0,
          longitude: 72.0,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
        final mockResponse = Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
        );

        when(mockBattery.getBatteryLevel()).thenAnswer((_) async => '80%');
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.always);
        when(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        )).thenAnswer((_) async => mockPosition);
        when(mockGlobalState.serverPath(any))
            .thenReturn('https://api.test/path');
        when(mockHttp.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => mockResponse);

        // Act
        await runnerHttp.runnerAppCurrentState(headers: customHeaders);

        // Assert
        verify(mockHttp.get(any, headers: customHeaders)).called(1);
      });

      test('should set is_fg parameter correctly', () async {
        // Arrange
        final mockPosition = Position(
          latitude: 19.0,
          longitude: 72.0,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
        final mockResponse = Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
        );

        when(mockBattery.getBatteryLevel()).thenAnswer((_) async => '75%');
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        when(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        )).thenAnswer((_) async => mockPosition);
        when(mockGlobalState.serverPath(any)).thenReturn('url');
        when(mockHttp.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => mockResponse);

        // Act - test with isFg=false
        await runnerHttp.runnerAppCurrentState(isFg: false);

        // Assert
        verify(mockGlobalState.serverPath(argThat(contains('is_fg=false')))).called(1);
      });
    });

    group('Edge Cases - Location services disabled', () {
      test('should make API call with null lat/lng when location service disabled',
          () async {
        // Arrange
        const expectedBattery = '90%';
        final mockResponse = Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
        );

        when(mockBattery.getBatteryLevel())
            .thenAnswer((_) async => expectedBattery);
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => false); // ❗ Disabled
        when(mockGlobalState.serverPath(any)).thenReturn('url');
        when(mockHttp.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await runnerHttp.runnerAppCurrentState();

        // Assert
        expect(result, isNotNull);

        // Should call API with null lat/lng
        verify(mockGlobalState.serverPath(
          argThat(contains('lat=null&lng=null')),
        )).called(1);

        // Should NOT attempt to get location
        verifyNever(mockGeolocator.checkPermission());
        verifyNever(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        ));
      });
    });

    group('Edge Cases - Location permission denied', () {
      test('should make API call with null lat/lng when permission denied',
          () async {
        // Arrange
        final mockResponse = Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
        );

        when(mockBattery.getBatteryLevel()).thenAnswer((_) async => '85%');
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.denied); // ❗ Denied
        when(mockGlobalState.serverPath(any)).thenReturn('url');
        when(mockHttp.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await runnerHttp.runnerAppCurrentState();

        // Assert
        expect(result, isNotNull);

        // Should NOT attempt to get position
        verifyNever(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        ));

        // Should call API with null lat/lng
        verify(mockGlobalState.serverPath(argThat(contains('lat=null&lng=null'))))
            .called(1);
      });
    });

    group('Error Handling - GPS timeout/error', () {
      test('should make API call with null lat/lng when GPS throws error',
          () async {
        // Arrange
        final mockResponse = Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
        );

        when(mockBattery.getBatteryLevel()).thenAnswer((_) async => '70%');
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.whileInUse);
        when(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        )).thenThrow(Exception('GPS timeout')); // ❗ GPS error
        when(mockGlobalState.serverPath(any)).thenReturn('url');
        when(mockHttp.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await runnerHttp.runnerAppCurrentState();

        // Assert
        expect(result, isNotNull);

        // Should swallow GPS error and continue with null location
        verify(mockGlobalState.serverPath(argThat(contains('lat=null&lng=null'))))
            .called(1);
      });
    });

    group('Error Handling - HTTP call failure', () {
      test('should return null when HTTP call throws exception', () async {
        // Arrange
        final mockPosition = Position(
          latitude: 19.0,
          longitude: 72.0,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        when(mockBattery.getBatteryLevel()).thenAnswer((_) async => '60%');
        when(mockGeolocator.isLocationServiceEnabled())
            .thenAnswer((_) async => true);
        when(mockGeolocator.checkPermission())
            .thenAnswer((_) async => LocationPermission.always);
        when(mockGeolocator.getCurrentPosition(
          desiredAccuracy: anyNamed('desiredAccuracy'),
          timeLimit: anyNamed('timeLimit'),
        )).thenAnswer((_) async => mockPosition);
        when(mockGlobalState.serverPath(any)).thenReturn('url');
        when(mockHttp.get(any, headers: anyNamed('headers')))
            .thenThrow(Exception('Network error')); // ❗ HTTP error

        // Act
        final result = await runnerHttp.runnerAppCurrentState();

        // Assert
        expect(result, isNull); // ✅ Should return null on error
      });
    });
  });
}

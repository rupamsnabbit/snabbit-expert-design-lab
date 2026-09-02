/**
 * Unit tests for RemoteConfigServiceTestable
 *
 * Purpose: Regression testing for RemoteConfigService getter methods before SNCON-91
 * Related: SNCON-92 - Regression tests before enhanced location tracking
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service_testable.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_wrapper.dart';

// Generate mocks
@GenerateMocks([IRemoteConfigWrapper])
import 'remote_config_service_testable_test.mocks.dart';

void main() {
  group('RemoteConfigServiceTestable.getInt', () {
    late MockIRemoteConfigWrapper mockConfig;
    late RemoteConfigServiceTestable service;

    setUp(() {
      mockConfig = MockIRemoteConfigWrapper();
      service = RemoteConfigServiceTestable(config: mockConfig);
    });

    group('Happy Path', () {
      test('should return value when config returns int', () {
        // Arrange
        const key = 'test_int_key';
        const expectedValue = 42;
        when(mockConfig.getInt(key)).thenReturn(expectedValue);

        // Act
        final result = service.getInt(key);

        // Assert
        expect(result, expectedValue);
        verify(mockConfig.getInt(key)).called(1);
      });

      test('should return custom default value when config returns null', () {
        // Arrange
        const key = 'missing_key';
        const customDefault = 100;
        when(mockConfig.getInt(key)).thenReturn(null);

        // Act
        final result = service.getInt(key, defaultValue: customDefault);

        // Assert
        expect(result, customDefault);
        verify(mockConfig.getInt(key)).called(1);
      });

      test('should return 0 as default when config returns null and no default provided', () {
        // Arrange
        const key = 'missing_key';
        when(mockConfig.getInt(key)).thenReturn(null);

        // Act
        final result = service.getInt(key);

        // Assert
        expect(result, 0);
      });
    });

    group('Edge Cases', () {
      test('should handle negative integers', () {
        // Arrange
        const key = 'negative_int';
        const expectedValue = -999;
        when(mockConfig.getInt(key)).thenReturn(expectedValue);

        // Act
        final result = service.getInt(key);

        // Assert
        expect(result, expectedValue);
      });

      test('should handle zero value', () {
        // Arrange
        const key = 'zero_value';
        when(mockConfig.getInt(key)).thenReturn(0);

        // Act
        final result = service.getInt(key);

        // Assert
        expect(result, 0);
      });

      test('should handle large integers', () {
        // Arrange
        const key = 'large_int';
        const expectedValue = 2147483647; // Max int32
        when(mockConfig.getInt(key)).thenReturn(expectedValue);

        // Act
        final result = service.getInt(key);

        // Assert
        expect(result, expectedValue);
      });
    });

    group('Error Handling', () {
      test('should return default when getInt throws exception', () {
        // Arrange
        const key = 'error_key';
        const customDefault = 50;
        when(mockConfig.getInt(key)).thenThrow(Exception('Config error'));

        // Act
        final result = service.getInt(key, defaultValue: customDefault);

        // Assert
        expect(result, customDefault);
      });

      test('should return 0 when getInt throws and no default provided', () {
        // Arrange
        const key = 'error_key';
        when(mockConfig.getInt(key)).thenThrow(Exception('Config error'));

        // Act
        final result = service.getInt(key);

        // Assert
        expect(result, 0);
      });
    });
  });

  group('RemoteConfigServiceTestable.getBool', () {
    late MockIRemoteConfigWrapper mockConfig;
    late RemoteConfigServiceTestable service;

    setUp(() {
      mockConfig = MockIRemoteConfigWrapper();
      service = RemoteConfigServiceTestable(config: mockConfig);
    });

    group('Happy Path', () {
      test('should return true when config returns true', () {
        // Arrange
        const key = 'test_bool_key';
        when(mockConfig.getBool(key)).thenReturn(true);

        // Act
        final result = service.getBool(key);

        // Assert
        expect(result, true);
        verify(mockConfig.getBool(key)).called(1);
      });

      test('should return false when config returns false', () {
        // Arrange
        const key = 'test_bool_key';
        when(mockConfig.getBool(key)).thenReturn(false);

        // Act
        final result = service.getBool(key);

        // Assert
        expect(result, false);
        verify(mockConfig.getBool(key)).called(1);
      });

      test('should return custom default value when config returns null', () {
        // Arrange
        const key = 'missing_key';
        const customDefault = true;
        when(mockConfig.getBool(key)).thenReturn(null);

        // Act
        final result = service.getBool(key, defaultValue: customDefault);

        // Assert
        expect(result, customDefault);
        verify(mockConfig.getBool(key)).called(1);
      });

      test('should return false as default when config returns null and no default provided', () {
        // Arrange
        const key = 'missing_key';
        when(mockConfig.getBool(key)).thenReturn(null);

        // Act
        final result = service.getBool(key);

        // Assert
        expect(result, false);
      });
    });

    group('Error Handling', () {
      test('should return default when getBool throws exception', () {
        // Arrange
        const key = 'error_key';
        const customDefault = true;
        when(mockConfig.getBool(key)).thenThrow(Exception('Config error'));

        // Act
        final result = service.getBool(key, defaultValue: customDefault);

        // Assert
        expect(result, customDefault);
      });

      test('should return false when getBool throws and no default provided', () {
        // Arrange
        const key = 'error_key';
        when(mockConfig.getBool(key)).thenThrow(Exception('Config error'));

        // Act
        final result = service.getBool(key);

        // Assert
        expect(result, false);
      });
    });
  });

  group('RemoteConfigServiceTestable.getString', () {
    late MockIRemoteConfigWrapper mockConfig;
    late RemoteConfigServiceTestable service;

    setUp(() {
      mockConfig = MockIRemoteConfigWrapper();
      service = RemoteConfigServiceTestable(config: mockConfig);
    });

    group('Happy Path', () {
      test('should return value when config returns string', () {
        // Arrange
        const key = 'test_string_key';
        const expectedValue = 'hello world';
        when(mockConfig.getString(key)).thenReturn(expectedValue);

        // Act
        final result = service.getString(key);

        // Assert
        expect(result, expectedValue);
        verify(mockConfig.getString(key)).called(1);
      });

      test('should return custom default when config returns null', () {
        // Arrange
        const key = 'missing_key';
        const customDefault = 'default_value';
        when(mockConfig.getString(key)).thenReturn(null);

        // Act
        final result = service.getString(key, defaultValue: customDefault);

        // Assert
        expect(result, customDefault);
      });

      test('should return empty string as default when config returns null', () {
        // Arrange
        const key = 'missing_key';
        when(mockConfig.getString(key)).thenReturn(null);

        // Act
        final result = service.getString(key);

        // Assert
        expect(result, '');
      });
    });

    group('Error Handling', () {
      test('should return default when getString throws exception', () {
        // Arrange
        const key = 'error_key';
        const customDefault = 'fallback';
        when(mockConfig.getString(key)).thenThrow(Exception('Config error'));

        // Act
        final result = service.getString(key, defaultValue: customDefault);

        // Assert
        expect(result, customDefault);
      });
    });
  });

  group('RemoteConfigKeys.isGoLiveV3Enabled (go-live webview gate)', () {
    late MockIRemoteConfigWrapper mockConfig;
    late RemoteConfigServiceTestable service;

    setUp(() {
      mockConfig = MockIRemoteConfigWrapper();
      service = RemoteConfigServiceTestable(config: mockConfig);
    });

    bool readGate() => service.getBool(
          RemoteConfigKeys.isGoLiveV3Enabled,
          defaultValue: false,
        );

    test('enables the go-live webview when the flag is true', () {
      when(mockConfig.getBool(RemoteConfigKeys.isGoLiveV3Enabled))
          .thenReturn(true);

      expect(readGate(), isTrue);
    });

    test('keeps the native flow when the flag is explicitly false', () {
      when(mockConfig.getBool(RemoteConfigKeys.isGoLiveV3Enabled))
          .thenReturn(false);

      expect(readGate(), isFalse);
    });

    test('keeps the native flow when the flag is unset (backward compatible)',
        () {
      when(mockConfig.getBool(RemoteConfigKeys.isGoLiveV3Enabled))
          .thenReturn(null);

      expect(readGate(), isFalse);
    });

    test('keeps the native flow when Remote Config throws', () {
      when(mockConfig.getBool(RemoteConfigKeys.isGoLiveV3Enabled))
          .thenThrow(Exception('Config error'));

      expect(readGate(), isFalse);
    });
  });

  group('RemoteConfigServiceTestable.getDouble', () {
    late MockIRemoteConfigWrapper mockConfig;
    late RemoteConfigServiceTestable service;

    setUp(() {
      mockConfig = MockIRemoteConfigWrapper();
      service = RemoteConfigServiceTestable(config: mockConfig);
    });

    group('Happy Path', () {
      test('should return value when config returns double', () {
        // Arrange
        const key = 'test_double_key';
        const expectedValue = 3.14159;
        when(mockConfig.getDouble(key)).thenReturn(expectedValue);

        // Act
        final result = service.getDouble(key);

        // Assert
        expect(result, expectedValue);
        verify(mockConfig.getDouble(key)).called(1);
      });

      test('should return custom default when config returns null', () {
        // Arrange
        const key = 'missing_key';
        const customDefault = 99.99;
        when(mockConfig.getDouble(key)).thenReturn(null);

        // Act
        final result = service.getDouble(key, defaultValue: customDefault);

        // Assert
        expect(result, customDefault);
      });

      test('should return 0.0 as default when config returns null', () {
        // Arrange
        const key = 'missing_key';
        when(mockConfig.getDouble(key)).thenReturn(null);

        // Act
        final result = service.getDouble(key);

        // Assert
        expect(result, 0.0);
      });
    });

    group('Error Handling', () {
      test('should return default when getDouble throws exception', () {
        // Arrange
        const key = 'error_key';
        const customDefault = 1.5;
        when(mockConfig.getDouble(key)).thenThrow(Exception('Config error'));

        // Act
        final result = service.getDouble(key, defaultValue: customDefault);

        // Assert
        expect(result, customDefault);
      });
    });
  });
}

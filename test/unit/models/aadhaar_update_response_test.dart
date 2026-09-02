import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/aadhaar_update_response.dart';

void main() {
  group('AadhaarUpdateResponse.fromJson', () {
    test('parses a verified response', () {
      // Arrange
      final json = {
        'document_id': 42,
        'status': 'verified',
        'aadhaar_number': 'XXXXXXXX1234',
      };

      // Act
      final result = AadhaarUpdateResponse.fromJson(json);

      // Assert
      expect(result.documentId, 42);
      expect(result.status, 'verified');
      expect(result.aadhaarNumber, 'XXXXXXXX1234');
      expect(result.isVerified, isTrue);
      expect(result.isRejected, isFalse);
      expect(result.isNameMismatched, isFalse);
    });

    test('flags a rejected response', () {
      // Arrange / Act
      final result = AadhaarUpdateResponse.fromJson({'status': 'rejected'});

      // Assert
      expect(result.isRejected, isTrue);
      expect(result.isVerified, isFalse);
      expect(result.isNameMismatched, isFalse);
    });

    test('flags a name_mismatched response', () {
      // Arrange / Act
      final result =
          AadhaarUpdateResponse.fromJson({'status': 'name_mismatched'});

      // Assert
      expect(result.isNameMismatched, isTrue);
      expect(result.isVerified, isFalse);
      expect(result.isRejected, isFalse);
    });

    test('treats status case-insensitively', () {
      // Arrange / Act
      final result = AadhaarUpdateResponse.fromJson({'status': 'VERIFIED'});

      // Assert
      expect(result.isVerified, isTrue);
    });

    test('parses document_id from a numeric string via anyValueToInt', () {
      // Arrange / Act
      final result = AadhaarUpdateResponse.fromJson({'document_id': '42'});

      // Assert
      expect(result.documentId, 42);
    });

    test('leaves fields null when absent and no status flag is set', () {
      // Arrange / Act
      final result = AadhaarUpdateResponse.fromJson({});

      // Assert
      expect(result.documentId, isNull);
      expect(result.status, isNull);
      expect(result.aadhaarNumber, isNull);
      expect(result.isVerified, isFalse);
      expect(result.isRejected, isFalse);
      expect(result.isNameMismatched, isFalse);
    });

    test('an unknown status sets none of the flags', () {
      // Arrange / Act
      final result = AadhaarUpdateResponse.fromJson({'status': 'pending'});

      // Assert
      expect(result.isVerified, isFalse);
      expect(result.isRejected, isFalse);
      expect(result.isNameMismatched, isFalse);
    });
  });
}

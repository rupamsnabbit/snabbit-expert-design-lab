import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/perfios_aadhaar_data.dart';

void main() {
  group('PerfiosAadhaarData.fromJson', () {
    test('parses the demographic fields used by the review screen', () {
      // Arrange — keys mirror the existing Perfios success response shape.
      final json = {
        'name': 'Ravi Kumar',
        'dob': '1990-01-01',
        'gender': 'M',
        'address': '12, MG Road, Bengaluru',
        'maskedAadhaarNumber': 'XXXXXXXX1234',
      };

      // Act
      final data = PerfiosAadhaarData.fromJson(json);

      // Assert
      expect(data.name, 'Ravi Kumar');
      expect(data.dob, '1990-01-01');
      expect(data.gender, 'M');
      expect(data.address, '12, MG Road, Bengaluru');
      expect(data.maskedAadhaarNumber, 'XXXXXXXX1234');
      expect(data.hasAnyData, isTrue);
    });

    test('is defensive — missing fields are null and hasAnyData is false', () {
      // Arrange / Act
      final data = PerfiosAadhaarData.fromJson({});

      // Assert
      expect(data.name, isNull);
      expect(data.dob, isNull);
      expect(data.gender, isNull);
      expect(data.address, isNull);
      expect(data.maskedAadhaarNumber, isNull);
      expect(data.hasAnyData, isFalse);
    });

    test('hasAnyData is true when at least one field is present', () {
      // Arrange / Act
      final data = PerfiosAadhaarData.fromJson({'name': 'Ravi Kumar'});

      // Assert
      expect(data.hasAnyData, isTrue);
    });
  });
}

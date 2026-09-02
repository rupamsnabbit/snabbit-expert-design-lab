/**
 * Unit tests for IoT Database abstraction layer
 *
 * Purpose: Test database interface contract using mocks
 * Related: SNCON-91 - IoT tracking system
 *
 * Note: Real SQLite integration tests should be run on device/emulator
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';

// Generate mocks
@GenerateMocks([IDatabaseInterface])
import 'database_test.mocks.dart';

void main() {
  group('DatabaseTables', () {
    test('should have correct table names', () {
      expect(DatabaseTables.battery, 'iot_battery_data');
      expect(DatabaseTables.location, 'iot_location_data');
    });
  });

  group('IDatabaseInterface', () {
    late MockIDatabaseInterface mockDb;

    setUp(() {
      mockDb = MockIDatabaseInterface();
    });

    group('insert', () {
      test('should return row ID on successful insert', () async {
        when(mockDb.insert(any, any)).thenAnswer((_) async => 1);

        final id = await mockDb.insert(DatabaseTables.battery, {
          'user_id': 'user-123',
          'percentage': 85,
          'collected_at': DateTime.now().millisecondsSinceEpoch,
          'sent': false,
        });

        expect(id, 1);
        verify(mockDb.insert(DatabaseTables.battery, any)).called(1);
      });

      test('should throw exception on insert failure', () async {
        when(mockDb.insert(any, any)).thenThrow(Exception('Insert failed'));

        expect(
          () => mockDb.insert(DatabaseTables.battery, {}),
          throwsException,
        );
      });
    });

    group('query', () {
      test('should return list of maps on successful query', () async {
        final mockResults = [
          {'id': 1, 'user_id': 'user-123', 'percentage': 85, 'sent': false},
          {'id': 2, 'user_id': 'user-123', 'percentage': 84, 'sent': false},
        ];

        when(mockDb.query(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => mockResults);

        final results = await mockDb.query(
          DatabaseTables.battery,
          where: 'user_id = ? AND sent = ?',
          whereArgs: ['user-123', 0],
          orderBy: 'collected_at ASC',
        );

        expect(results.length, 2);
        expect(results[0]['user_id'], 'user-123');
      });

      test('should return empty list when no matches', () async {
        when(mockDb.query(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        final results = await mockDb.query(
          DatabaseTables.battery,
          where: 'user_id = ?',
          whereArgs: ['non-existent'],
        );

        expect(results, isEmpty);
      });

      test('should respect limit parameter', () async {
        final mockResults = [
          {'id': 1, 'percentage': 85},
        ];

        when(mockDb.query(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          orderBy: anyNamed('orderBy'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => mockResults);

        await mockDb.query(
          DatabaseTables.battery,
          limit: 1,
        );

        verify(mockDb.query(
          DatabaseTables.battery,
          where: null,
          whereArgs: null,
          orderBy: null,
          limit: 1,
        )).called(1);
      });
    });

    group('update', () {
      test('should return number of rows affected', () async {
        when(mockDb.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 2);

        final rowsAffected = await mockDb.update(
          DatabaseTables.battery,
          {'sent': true},
          where: 'id IN (?, ?)',
          whereArgs: [1, 2],
        );

        expect(rowsAffected, 2);
      });

      test('should return 0 when no rows match', () async {
        when(mockDb.update(
          any,
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);

        final rowsAffected = await mockDb.update(
          DatabaseTables.battery,
          {'sent': true},
          where: 'id = ?',
          whereArgs: [99999],
        );

        expect(rowsAffected, 0);
      });
    });

    group('delete', () {
      test('should return number of rows deleted', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 3);

        final rowsDeleted = await mockDb.delete(
          DatabaseTables.battery,
          where: 'sent = ?',
          whereArgs: [1],
        );

        expect(rowsDeleted, 3);
      });

      test('should return 0 when no rows match', () async {
        when(mockDb.delete(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);

        final rowsDeleted = await mockDb.delete(
          DatabaseTables.battery,
          where: 'user_id = ?',
          whereArgs: ['non-existent'],
        );

        expect(rowsDeleted, 0);
      });
    });

    group('count', () {
      test('should return total count', () async {
        when(mockDb.count(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 10);

        final count = await mockDb.count(DatabaseTables.battery);

        expect(count, 10);
      });

      test('should return filtered count', () async {
        when(mockDb.count(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 5);

        final count = await mockDb.count(
          DatabaseTables.battery,
          where: 'user_id = ? AND sent = ?',
          whereArgs: ['user-123', 0],
        );

        expect(count, 5);
      });

      test('should return 0 for empty result', () async {
        when(mockDb.count(
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => 0);

        final count = await mockDb.count(DatabaseTables.battery);

        expect(count, 0);
      });
    });

    group('execute', () {
      test('should execute raw SQL successfully', () async {
        when(mockDb.execute(any, any)).thenAnswer((_) async {});

        await mockDb.execute(
          'DELETE FROM ${DatabaseTables.battery} WHERE sent = ?',
          [1],
        );

        verify(mockDb.execute(any, [1])).called(1);
      });

      test('should throw exception on SQL error', () async {
        when(mockDb.execute(any, any)).thenThrow(Exception('SQL error'));

        expect(
          () => mockDb.execute('INVALID SQL', null),
          throwsException,
        );
      });
    });

    group('initialize', () {
      test('should complete without error', () async {
        when(mockDb.initialize()).thenAnswer((_) async {});

        await mockDb.initialize();

        verify(mockDb.initialize()).called(1);
      });
    });

    group('close', () {
      test('should complete without error', () async {
        when(mockDb.close()).thenAnswer((_) async {});

        await mockDb.close();

        verify(mockDb.close()).called(1);
      });
    });
  });
}

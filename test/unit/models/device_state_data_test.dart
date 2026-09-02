import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/device_state_data.dart';

void main() {
  group('DeviceStateData', () {
    const testUserId = 'user-123';
    const testCollectedAt = 1700000000000;

    group('toMap', () {
      test('includes all fields when fully populated', () {
        // Arrange
        final data = DeviceStateData(
          id: 42,
          userId: testUserId,
          locationServicesOn: true,
          mobileDataOn: true,
          networkType: 'wifi',
          collectedAt: testCollectedAt,
          sent: false,
        );

        // Act
        final map = data.toMap();

        // Assert
        expect(map['id'], 42);
        expect(map['user_id'], testUserId);
        expect(map['location_services_on'], true);
        expect(map['mobile_data_on'], true);
        expect(map['network_type'], 'wifi');
        expect(map['collected_at'], testCollectedAt);
        expect(map['sent'], false);
      });

      test('includes null data fields when collection failed', () {
        // Arrange — all device state fields null (collection errors)
        final data = DeviceStateData(
          id: 1,
          userId: testUserId,
          locationServicesOn: null,
          mobileDataOn: null,
          networkType: null,
          collectedAt: testCollectedAt,
          sent: false,
        );

        // Act
        final map = data.toMap();

        // Assert — nulls must be present in the map so the DB column is written
        expect(map.containsKey('location_services_on'), isTrue);
        expect(map['location_services_on'], isNull);
        expect(map.containsKey('mobile_data_on'), isTrue);
        expect(map['mobile_data_on'], isNull);
        expect(map.containsKey('network_type'), isTrue);
        expect(map['network_type'], isNull);
      });

      test('excludes id when id is 0 (new record)', () {
        // Arrange
        final data = DeviceStateData(
          userId: testUserId,
          collectedAt: testCollectedAt,
        );

        // Act
        final map = data.toMap();

        // Assert
        expect(map.containsKey('id'), isFalse);
      });

      test('includes id when id is non-zero (existing record)', () {
        // Arrange
        final data = DeviceStateData(
          id: 7,
          userId: testUserId,
          collectedAt: testCollectedAt,
        );

        // Act
        final map = data.toMap();

        // Assert
        expect(map.containsKey('id'), isTrue);
        expect(map['id'], 7);
      });

      test('marks sent=true correctly', () {
        // Arrange
        final data = DeviceStateData(
          id: 3,
          userId: testUserId,
          collectedAt: testCollectedAt,
          sent: true,
        );

        // Act
        final map = data.toMap();

        // Assert
        expect(map['sent'], true);
      });
    });

    group('fromMap', () {
      test('creates instance with all fields populated', () {
        // Arrange
        final map = <String, dynamic>{
          'id': 5,
          'user_id': testUserId,
          'location_services_on': true,
          'mobile_data_on': false,
          'network_type': 'mobile',
          'collected_at': testCollectedAt,
          'sent': false,
        };

        // Act
        final data = DeviceStateData.fromMap(map);

        // Assert
        expect(data.id, 5);
        expect(data.userId, testUserId);
        expect(data.locationServicesOn, true);
        expect(data.mobileDataOn, false);
        expect(data.networkType, 'mobile');
        expect(data.collectedAt, testCollectedAt);
        expect(data.sent, false);
      });

      test('creates instance with null device-state fields from database', () {
        // Arrange — DB stores NULL when collection failed
        final map = <String, dynamic>{
          'id': 6,
          'user_id': testUserId,
          'location_services_on': null,
          'mobile_data_on': null,
          'network_type': null,
          'collected_at': testCollectedAt,
          'sent': false,
        };

        // Act
        final data = DeviceStateData.fromMap(map);

        // Assert
        expect(data.locationServicesOn, isNull);
        expect(data.mobileDataOn, isNull);
        expect(data.networkType, isNull);
      });

      test('defaults sent to false when absent from map', () {
        // Arrange — sent key missing (e.g. legacy row)
        final map = <String, dynamic>{
          'id': 9,
          'user_id': testUserId,
          'location_services_on': null,
          'mobile_data_on': null,
          'network_type': null,
          'collected_at': testCollectedAt,
          'sent': null,
        };

        // Act
        final data = DeviceStateData.fromMap(map);

        // Assert
        expect(data.sent, false);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        // Arrange
        final original = DeviceStateData(
          id: 1,
          userId: testUserId,
          locationServicesOn: false,
          mobileDataOn: false,
          networkType: 'none',
          collectedAt: testCollectedAt,
          sent: false,
        );

        // Act
        final updated = original.copyWith(
          sent: true,
          networkType: 'wifi',
        );

        // Assert
        expect(updated.sent, true);
        expect(updated.networkType, 'wifi');
      });

      test('preserves unchanged fields when only some are updated', () {
        // Arrange
        final original = DeviceStateData(
          id: 2,
          userId: testUserId,
          locationServicesOn: true,
          mobileDataOn: true,
          networkType: 'wifi',
          collectedAt: testCollectedAt,
          sent: false,
        );

        // Act — only update sent
        final updated = original.copyWith(sent: true);

        // Assert — all other fields unchanged
        expect(updated.id, original.id);
        expect(updated.userId, original.userId);
        expect(updated.locationServicesOn, original.locationServicesOn);
        expect(updated.mobileDataOn, original.mobileDataOn);
        expect(updated.networkType, original.networkType);
        expect(updated.collectedAt, original.collectedAt);
        expect(updated.sent, true);
      });

      test('can update id independently', () {
        // Arrange
        final original = DeviceStateData(
          userId: testUserId,
          collectedAt: testCollectedAt,
        );

        // Act
        final withId = original.copyWith(id: 99);

        // Assert
        expect(withId.id, 99);
        expect(withId.userId, original.userId);
        expect(withId.collectedAt, original.collectedAt);
      });
    });

    group('collectionCycleId', () {
      const testCycleId = 1700000000005;

      test('toMap includes collection_cycle_id when set', () {
        final data = DeviceStateData(
          userId: testUserId,
          collectedAt: testCollectedAt,
          collectionCycleId: testCycleId,
        );

        expect(data.toMap()['collection_cycle_id'], testCycleId);
      });

      test('toMap omits collection_cycle_id when null', () {
        // Pre-v4 / fg-fallback rows have no cycle id; the key must be absent so
        // the backend reads its absence as an ungroupable singleton.
        final data = DeviceStateData(
          userId: testUserId,
          collectedAt: testCollectedAt,
        );

        expect(data.toMap().containsKey('collection_cycle_id'), isFalse);
      });

      test('fromMap reads collection_cycle_id', () {
        final data = DeviceStateData.fromMap(<String, dynamic>{
          'id': 1,
          'user_id': testUserId,
          'location_services_on': true,
          'mobile_data_on': true,
          'network_type': 'wifi',
          'collected_at': testCollectedAt,
          'collection_cycle_id': testCycleId,
          'sent': false,
        });

        expect(data.collectionCycleId, testCycleId);
      });

      test('fromMap yields null collection_cycle_id for legacy rows', () {
        // Rows collected before the v4 migration have no such column.
        final data = DeviceStateData.fromMap(<String, dynamic>{
          'id': 1,
          'user_id': testUserId,
          'location_services_on': true,
          'mobile_data_on': true,
          'network_type': 'wifi',
          'collected_at': testCollectedAt,
          'sent': false,
        });

        expect(data.collectionCycleId, isNull);
      });
    });
  });
}

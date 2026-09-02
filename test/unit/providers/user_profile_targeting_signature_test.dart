import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/providers/user_profile.dart';

String signature({
  int? clusterId = 1,
  int? regionId = 2,
  int? trainingCenterId = 3,
  int? serviceId = 4,
  int? versionCode = 161,
}) =>
    UserProfileProvider.targetingSignature(
      clusterId: clusterId,
      regionId: regionId,
      trainingCenterId: trainingCenterId,
      serviceId: serviceId,
      versionCode: versionCode,
    );

void main() {
  group('UserProfileProvider.targetingSignature', () {
    test('is stable for identical inputs (no spurious forced refetch)', () {
      expect(signature(), signature());
    });

    test('changes when the version code changes — the upgrade case', () {
      expect(signature(versionCode: 161), isNot(signature(versionCode: 162)));
    });

    test('still changes for each pre-existing targeting field', () {
      final base = signature();
      expect(signature(clusterId: 99), isNot(base));
      expect(signature(regionId: 99), isNot(base));
      expect(signature(trainingCenterId: 99), isNot(base));
      expect(signature(serviceId: 99), isNot(base));
    });

    test('a null version code is stable, so it does not force a refetch loop',
        () {
      expect(signature(versionCode: null), signature(versionCode: null));
      expect(signature(versionCode: null), isNot(signature(versionCode: 161)));
    });

    test('nulls do not collide with adjacent fields shifting position', () {
      // Guards against a delimiter-free join: (1, null) must not equal
      // (null, 1) for any neighbouring pair.
      expect(
        signature(clusterId: 1, regionId: null),
        isNot(signature(clusterId: null, regionId: 1)),
      );
      expect(
        signature(serviceId: 4, versionCode: null),
        isNot(signature(serviceId: null, versionCode: 4)),
      );
    });
  });
}

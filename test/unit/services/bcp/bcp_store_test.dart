import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/bcp/bcp_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late BcpStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = BcpStore(prefs);
  });

  group('BcpStore.load', () {
    test('returns empty map when key absent', () async {
      expect(await store.load(), isEmpty);
    });

    test('returns parsed entries that are still in the future', () async {
      final future = DateTime.now().add(const Duration(seconds: 30));
      await prefs.setString(
        BcpStore.storageKey,
        json.encode({'api/v1/x': future.millisecondsSinceEpoch}),
      );
      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded['api/v1/x']!.millisecondsSinceEpoch,
          future.millisecondsSinceEpoch);
    });

    test('prunes expired entries on load', () async {
      final past = DateTime.now().subtract(const Duration(seconds: 30));
      final future = DateTime.now().add(const Duration(seconds: 30));
      await prefs.setString(
        BcpStore.storageKey,
        json.encode({
          'api/v1/old': past.millisecondsSinceEpoch,
          'api/v1/new': future.millisecondsSinceEpoch,
        }),
      );
      final loaded = await store.load();
      expect(loaded.keys, contains('api/v1/new'));
      expect(loaded.keys, isNot(contains('api/v1/old')));
    });

    test('returns empty map on malformed JSON', () async {
      await prefs.setString(BcpStore.storageKey, 'not-json');
      expect(await store.load(), isEmpty);
    });

    test('returns empty map when JSON is not an object', () async {
      await prefs.setString(BcpStore.storageKey, '["a","b"]');
      expect(await store.load(), isEmpty);
    });

    test('drops entries with non-int values', () async {
      final future = DateTime.now().add(const Duration(seconds: 30));
      await prefs.setString(
        BcpStore.storageKey,
        json.encode({
          'api/v1/good': future.millisecondsSinceEpoch,
          'api/v1/bad': 'not-a-number',
        }),
      );
      final loaded = await store.load();
      expect(loaded.keys, ['api/v1/good']);
    });
  });

  group('BcpStore.save', () {
    test('writes future entries as ms-since-epoch', () async {
      final future = DateTime.now().add(const Duration(seconds: 30));
      await store.save({'api/v1/x': future});
      final raw = prefs.getString(BcpStore.storageKey)!;
      final decoded = json.decode(raw) as Map<String, dynamic>;
      expect(decoded['api/v1/x'], future.millisecondsSinceEpoch);
    });

    test('prunes expired entries before writing', () async {
      final past = DateTime.now().subtract(const Duration(seconds: 30));
      final future = DateTime.now().add(const Duration(seconds: 30));
      await store.save({
        'api/v1/old': past,
        'api/v1/new': future,
      });
      final raw = prefs.getString(BcpStore.storageKey)!;
      final decoded = json.decode(raw) as Map<String, dynamic>;
      expect(decoded.keys, ['api/v1/new']);
    });

    test('removes the key entirely when all entries are expired', () async {
      final past = DateTime.now().subtract(const Duration(seconds: 30));
      await prefs.setString(BcpStore.storageKey, '{"stale":1}');
      await store.save({'api/v1/old': past});
      expect(prefs.containsKey(BcpStore.storageKey), isFalse);
    });

    test('removes the key entirely when input is empty', () async {
      await prefs.setString(BcpStore.storageKey, '{"stale":1}');
      await store.save({});
      expect(prefs.containsKey(BcpStore.storageKey), isFalse);
    });
  });

  group('BcpStore.clear', () {
    test('removes the storage key', () async {
      await prefs.setString(BcpStore.storageKey, '{"x":1}');
      await store.clear();
      expect(prefs.containsKey(BcpStore.storageKey), isFalse);
    });

    test('is a no-op when key is already absent', () async {
      await store.clear();
      expect(prefs.containsKey(BcpStore.storageKey), isFalse);
    });
  });

  group('BcpStore round-trip', () {
    test('save then load returns equivalent map', () async {
      final future1 = DateTime.now().add(const Duration(seconds: 10));
      final future2 = DateTime.now().add(const Duration(seconds: 60));
      await store.save({'api/v1/a': future1, 'api/v1/b': future2});
      final loaded = await store.load();
      expect(loaded['api/v1/a']!.millisecondsSinceEpoch,
          future1.millisecondsSinceEpoch);
      expect(loaded['api/v1/b']!.millisecondsSinceEpoch,
          future2.millisecondsSinceEpoch);
    });
  });
}

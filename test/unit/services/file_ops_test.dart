import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:snabbit_runner/services/file_ops.dart';

String _json(List<Map<String, dynamic>> contacts) =>
    jsonEncode({'contacts': contacts});

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('reduceStoredContactsJson', () {
    test('reduces to first phone, whitespace-stripped, name trimmed', () {
      final result = reduceStoredContactsJson(_json([
        {
          'name': '  Akshay  ',
          'phones': ['90000 11111', '222'],
        },
      ]));

      expect(result, [
        {'name': 'Akshay', 'phone': '9000011111'},
      ]);
    });

    test('skips contacts with no phones', () {
      final result = reduceStoredContactsJson(_json([
        {'name': 'NoPhone', 'phones': <String>[]},
        {
          'name': 'Liam',
          'phones': ['12345'],
        },
      ]));

      expect(result, [
        {'name': 'Liam', 'phone': '12345'},
      ]);
    });

    test('skips a contact whose phone is only whitespace', () {
      final result = reduceStoredContactsJson(_json([
        {
          'name': 'Blank',
          'phones': ['   '],
        },
        {
          'name': 'Olivia',
          'phones': ['999'],
        },
      ]));

      expect(result, [
        {'name': 'Olivia', 'phone': '999'},
      ]);
    });

    test('de-duplicates the same normalized number across contacts', () {
      final result = reduceStoredContactsJson(_json([
        {
          'name': 'Ava',
          'phones': ['90000 11111'],
        },
        {
          'name': 'Ava (work)',
          'phones': ['9000011111'],
        },
        {
          'name': 'Ben',
          'phones': ['222'],
        },
      ]));

      expect(result, [
        {'name': 'Ava', 'phone': '9000011111'},
        {'name': 'Ben', 'phone': '222'},
      ]);
    });

    test('skips a null phone entry without emitting a "null" number', () {
      final result = reduceStoredContactsJson(_json([
        {
          'name': 'Corrupt',
          'phones': [null],
        },
        {
          'name': 'Maya',
          'phones': ['777'],
        },
      ]));

      expect(result, [
        {'name': 'Maya', 'phone': '777'},
      ]);
    });

    test('defaults a missing name to empty string', () {
      final result = reduceStoredContactsJson(_json([
        {
          'phones': ['555'],
        },
      ]));

      expect(result, [
        {'name': '', 'phone': '555'},
      ]);
    });

    test('returns empty list when the contacts key is missing/invalid', () {
      expect(reduceStoredContactsJson(jsonEncode({'other': 1})), isEmpty);
      expect(reduceStoredContactsJson(jsonEncode({'contacts': 'nope'})),
          isEmpty);
    });

    test('returns empty list for non-map top-level JSON', () {
      expect(reduceStoredContactsJson(jsonEncode([1, 2, 3])), isEmpty);
      expect(reduceStoredContactsJson(jsonEncode('a string')), isEmpty);
    });
  });

  group('encodeContactsJson → reduceStoredContactsJson round-trip', () {
    test('encoded envelope is decodable back into the picker shape', () {
      final encoded = encodeContactsJson([
        {
          'name': '  Akshay  ',
          'phones': ['90000 11111', '222'],
        },
        {
          'name': 'Ben',
          'phones': ['333'],
        },
      ]);

      expect(reduceStoredContactsJson(encoded), [
        {'name': 'Akshay', 'phone': '9000011111'},
        {'name': 'Ben', 'phone': '333'},
      ]);
    });
  });

  group('refreshContactsFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_ops_test_');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('does not refetch when referral.json already exists', () async {
      // A warm (even reduce-empty) file must short-circuit the populate. If the
      // exists-gate regressed, execution would fall through to
      // FlutterContacts.getContacts() and throw MissingPluginException here.
      final file = File('${tempDir.path}/referral.json');
      const original = '{"contacts":[{"name":"Cached","phones":["111"]}]}';
      await file.writeAsString(original);

      await refreshContactsFile();

      expect(await file.readAsString(), original); // untouched, no refetch
    });
  });
}

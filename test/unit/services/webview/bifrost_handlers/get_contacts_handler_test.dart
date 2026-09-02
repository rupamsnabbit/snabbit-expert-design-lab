import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/get_contacts_handler.dart';

import '../test_channel_mocks.dart';

/// Returns a queue-backed permission requester: each call pops the next status,
/// so re-request scenarios (denied → resolve → granted) can be modelled.
PermissionRequester _statuses(List<PermissionStatus> queue) {
  final pending = List<PermissionStatus>.from(queue);
  return (permission) async {
    expect(permission, Permission.contacts);
    return pending.length == 1 ? pending.first : pending.removeAt(0);
  };
}

/// Reader that returns each queued list in turn (last one repeats), modelling a
/// miss (empty) followed by a populated read.
ContactsReader _reads(List<List<Map<String, String>>> queue) {
  final pending = List<List<Map<String, String>>>.from(queue);
  return () async => pending.length == 1 ? pending.first : pending.removeAt(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  installTestChannelMocks();

  group('GetContactsHandler', () {
    test('is an RPC handler named "getContacts"', () {
      final h = GetContactsHandler();
      expect(h.pattern, BifrostPattern.rpc);
      expect(h.actionName, 'getContacts');
    });

    test('returns the persisted contacts from the reader', () async {
      final h = GetContactsHandler(
        permissionRequester: _statuses([PermissionStatus.granted]),
        contactsReader: () async => [
          {'name': 'Akshay', 'phone': '8040683308'},
          {'name': 'Akash', 'phone': '9000011111'},
        ],
        contactsPopulator: () async => fail('must not populate on a cache hit'),
      );

      final result = await h.handle(const {});

      expect(result.error, isNull);
      expect(result.data, {
        'contacts': [
          {'name': 'Akshay', 'phone': '8040683308'},
          {'name': 'Akash', 'phone': '9000011111'},
        ],
      });
    });

    test('populates via the sync then re-reads on a miss', () async {
      var populated = 0;
      final h = GetContactsHandler(
        permissionRequester: _statuses([PermissionStatus.granted]),
        contactsReader: _reads([
          const [], // not synced yet
          [
            {'name': 'Mason', 'phone': '333'},
          ],
        ]),
        contactsPopulator: () async => populated++,
      );

      final result = await h.handle(const {});

      expect(populated, 1);
      expect(result.data?['contacts'], [
        {'name': 'Mason', 'phone': '333'},
      ]);
    });

    test('still empty after populate → empty contacts list', () async {
      final h = GetContactsHandler(
        permissionRequester: _statuses([PermissionStatus.granted]),
        contactsReader: () async => const [],
        contactsPopulator: () async {},
      );

      final result = await h.handle(const {});

      expect(result.error, isNull);
      expect(result.data, {'contacts': <Map<String, String>>[]});
    });

    test('treats limited (partial) access as readable', () async {
      final h = GetContactsHandler(
        permissionRequester: _statuses([PermissionStatus.limited]),
        contactsReader: () async => [
          {'name': 'Ethan', 'phone': '222'},
        ],
      );

      final result = await h.handle(const {});

      expect(result.error, isNull);
      expect(result.data?['contacts'], hasLength(1));
    });

    test('treats provisional access as readable', () async {
      final h = GetContactsHandler(
        permissionRequester: _statuses([PermissionStatus.provisional]),
        contactsReader: () async => [
          {'name': 'Lucas', 'phone': '444'},
        ],
      );

      final result = await h.handle(const {});

      expect(result.error, isNull);
      expect(result.data?['contacts'], hasLength(1));
    });

    test(
        'denied with no rationale handler returns PERMISSION_DENIED '
        'without reading contacts', () async {
      var read = false;
      final h = GetContactsHandler(
        permissionRequester: _statuses([PermissionStatus.denied]),
        contactsReader: () async {
          read = true;
          return const [];
        },
      );

      final result = await h.handle(const {});

      expect(read, isFalse);
      expect(result.data, isNull);
      expect(result.error?.code, BifrostErrorCodes.permissionDenied);
      expect(result.error?.details?['permission'], 'contacts');
      expect(result.error?.details?['status'], 'denied');
    });

    test(
      'denied → rationale resolves → re-request granted → reads contacts',
      () async {
        var sheetShown = false;
        final h = GetContactsHandler(
          // First request denied, second (after settings) granted.
          permissionRequester: _statuses([
            PermissionStatus.denied,
            PermissionStatus.granted,
          ]),
          onPermissionDenied: (status) async {
            sheetShown = true;
            expect(status, PermissionStatus.denied);
            return true; // user resolved in settings
          },
          contactsReader: () async => [
            {'name': 'Mason', 'phone': '333'},
          ],
        );

        final result = await h.handle(const {});

        expect(sheetShown, isTrue);
        expect(result.error, isNull);
        expect(result.data?['contacts'], [
          {'name': 'Mason', 'phone': '333'},
        ]);
      },
    );

    test(
      'denied → rationale resolves → still denied → PERMISSION_DENIED',
      () async {
        var read = false;
        final h = GetContactsHandler(
          permissionRequester: _statuses([
            PermissionStatus.denied,
            PermissionStatus.permanentlyDenied,
          ]),
          onPermissionDenied: (_) async => true,
          contactsReader: () async {
            read = true;
            return const [];
          },
        );

        final result = await h.handle(const {});

        expect(read, isFalse);
        expect(result.error?.code, BifrostErrorCodes.permissionDenied);
        expect(result.error?.details?['status'], 'permanentlyDenied');
      },
    );

    test(
      'denied → rationale gives up (false) → PERMISSION_DENIED, no re-request',
      () async {
        var requestCount = 0;
        final h = GetContactsHandler(
          permissionRequester: (permission) async {
            requestCount++;
            return PermissionStatus.denied;
          },
          onPermissionDenied: (_) async => false, // user dismissed sheet
          contactsReader: () async => const [],
        );

        final result = await h.handle(const {});

        expect(requestCount, 1); // no re-request after give-up
        expect(result.error?.code, BifrostErrorCodes.permissionDenied);
      },
    );

    test(
      'read failure → sanitized INTERNAL_ERROR and reports to Crashlytics',
      () async {
        Object? reportedError;
        final h = GetContactsHandler(
          permissionRequester: _statuses([PermissionStatus.granted]),
          contactsReader: () async => throw StateError('raw plugin boom'),
          errorReporter: (exception, stack, {reason, fatal = false}) async {
            reportedError = exception;
          },
        );

        final result = await h.handle(const {});

        expect(result.data, isNull);
        expect(result.error?.code, BifrostErrorCodes.internalError);
        expect(result.error?.message, 'Failed to fetch contacts');
        expect(result.error?.message, isNot(contains('raw plugin boom')));
        expect(reportedError, isA<StateError>());
      },
    );
  });
}

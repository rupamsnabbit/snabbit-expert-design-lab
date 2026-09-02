import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/permission_request_handler.dart';

class _RequestCall {
  _RequestCall(this.permission);
  final Permission permission;
}

PermissionRequestHandler _handler({
  PermissionStatus status = PermissionStatus.granted,
  List<_RequestCall>? calls,
}) {
  return PermissionRequestHandler(
    requestPermission: (permission) async {
      calls?.add(_RequestCall(permission));
      return status;
    },
  );
}

void main() {
  group('PermissionRequestHandler', () {
    test('is an RPC handler named "permissionRequest"', () {
      final h = _handler();
      expect(h.pattern, BifrostPattern.rpc);
      expect(h.actionName, 'permissionRequest');
    });

    test('routes "camera" to Permission.camera and returns granted',
        () async {
      final calls = <_RequestCall>[];
      final h = _handler(
        status: PermissionStatus.granted,
        calls: calls,
      );

      final result = await h.handle({'permission': 'camera'});

      expect(calls.single.permission, Permission.camera);
      expect(result.error, isNull);
      expect(result.data, {'status': 'granted'});
    });

    test('maps denied status through unchanged', () async {
      final h = _handler(status: PermissionStatus.denied);
      final result = await h.handle({'permission': 'location'});
      expect(result.data, {'status': 'denied'});
    });

    test('maps permanentlyDenied status through unchanged', () async {
      final h = _handler(status: PermissionStatus.permanentlyDenied);
      final result = await h.handle({'permission': 'microphone'});
      expect(result.data, {'status': 'permanentlyDenied'});
    });

    test('treats provisional and limited as granted (some access allowed)',
        () async {
      final provisional = await _handler(status: PermissionStatus.provisional)
          .handle({'permission': 'notifications'});
      final limited =
          await _handler(status: PermissionStatus.limited).handle({
        'permission': 'photos',
      });

      expect(provisional.data, {'status': 'granted'});
      expect(limited.data, {'status': 'granted'});
    });

    test('missing permission field returns INVALID_ARGS', () async {
      final calls = <_RequestCall>[];
      final h = _handler(calls: calls);

      final result = await h.handle(const {});

      expect(calls, isEmpty);
      expect(result.error?.code, BifrostErrorCodes.invalidArgs);
    });

    test('empty permission string returns INVALID_ARGS', () async {
      final result = await _handler().handle({'permission': ''});
      expect(result.error?.code, BifrostErrorCodes.invalidArgs);
    });

    test('non-string permission returns INVALID_ARGS', () async {
      final result = await _handler().handle({'permission': 42});
      expect(result.error?.code, BifrostErrorCodes.invalidArgs);
    });

    test('unsupported permission name returns INVALID_ARGS with details',
        () async {
      final calls = <_RequestCall>[];
      final h = _handler(calls: calls);

      final result = await h.handle({'permission': 'bluetooth'});

      expect(calls, isEmpty);
      expect(result.error?.code, BifrostErrorCodes.invalidArgs);
      expect(result.error?.message, contains('Unsupported permission'));
      expect(result.error?.details?['requested'], 'bluetooth');
      expect(result.error?.details?['supported'], isA<List>());
    });

    test('every supported permission name maps to a Permission', () async {
      for (final name in PermissionRequestHandler.supportedPermissions) {
        final calls = <_RequestCall>[];
        final h = _handler(calls: calls);
        await h.handle({'permission': name});
        expect(calls, hasLength(1),
            reason: 'supported permission $name should dispatch');
      }
    });
  });
}

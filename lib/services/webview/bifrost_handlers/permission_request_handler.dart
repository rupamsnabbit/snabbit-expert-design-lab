import 'package:permission_handler/permission_handler.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// Abstraction over `permission_handler` so tests can inject a fake without
/// hitting the platform. Production default forwards to the real plugin.
typedef PermissionStatusFetcher = Future<PermissionStatus> Function(
  Permission permission,
);

Future<PermissionStatus> _defaultRequestPermission(
  Permission permission,
) async {
  return permission.request();
}

/// RPC handler for `permissionRequest`. Web asks native to request
/// (and possibly prompt for) a device permission. See proposal §2.
///
/// Wire shape:
/// - request:  `{ "permission": "camera" }`
/// - response: `{ "status": "granted" | "denied" | "permanentlyDenied" | "restricted" | "unknown" }`
///
/// Android-only — iOS is out of scope for this app. The set of
/// recognised permission names is intentionally tight; adding a new
/// one is a single-line change to [_supported].
class PermissionRequestHandler implements BifrostHandler {
  PermissionRequestHandler({
    PermissionStatusFetcher? requestPermission,
  }) : _requestPermission = requestPermission ?? _defaultRequestPermission;

  final PermissionStatusFetcher _requestPermission;

  /// String → `Permission` mapping. Keep the set tight — every entry is
  /// a new capability web can ask the runner to grant.
  static const Map<String, Permission> _supported = {
    'camera': Permission.camera,
    'location': Permission.location,
    'locationWhenInUse': Permission.locationWhenInUse,
    'locationAlways': Permission.locationAlways,
    'photos': Permission.photos,
    'microphone': Permission.microphone,
    'notifications': Permission.notification,
    'contacts': Permission.contacts,
    'storage': Permission.storage,
  };

  static Iterable<String> get supportedPermissions => _supported.keys;

  @override
  String get actionName => WebViewConstants.eventPermissionRequest;

  @override
  BifrostPattern get pattern => BifrostPattern.rpc;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    final name = data['permission'];
    if (name is! String || name.isEmpty) {
      return const BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.invalidArgs,
          message: "Missing or invalid 'permission'",
        ),
      );
    }

    final permission = _supported[name];
    if (permission == null) {
      return BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.invalidArgs,
          message: 'Unsupported permission: $name',
          details: {
            'requested': name,
            'supported': _supported.keys.toList(),
          },
        ),
      );
    }

    final status = await _requestPermission(permission);
    return BifrostResult(data: {'status': _statusToWire(status)});
  }

  static String _statusToWire(PermissionStatus status) {
    // provisional / limited → 'granted': partial access counts as access
    // for the web's purposes (e.g. iOS 14+ "Allow only selected photos").
    // Other cases match the enum name 1:1, so let Dart emit it.
    if (status == PermissionStatus.provisional ||
        status == PermissionStatus.limited) {
      return 'granted';
    }
    return status.name;
  }
}

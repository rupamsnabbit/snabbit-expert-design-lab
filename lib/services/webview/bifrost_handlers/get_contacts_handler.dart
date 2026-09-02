import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snabbit_runner/services/file_ops.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// Reads the persisted contacts (referral.json) reduced to the picker shape.
typedef ContactsReader = Future<List<Map<String, String>>> Function();

/// Populates referral.json via the existing background sync when it's absent.
typedef ContactsPopulator = Future<void> Function();

/// Returns the [PermissionStatus] after requesting the given permission.
typedef PermissionRequester = Future<PermissionStatus> Function(
    Permission permission);

/// Called when contacts permission is denied. Gives the UI layer a chance to
/// show a bottom sheet guiding the user to app settings. Returns `true` if the
/// user resolved the permission (came back from settings with contacts
/// granted), `false` to give up and return `PERMISSION_DENIED` to the web.
typedef PermissionDeniedHandler = Future<bool> Function(
    PermissionStatus status);

Future<PermissionStatus> _defaultRequestPermission(
  Permission permission,
) async =>
    permission.request();

typedef ErrorReporter = Future<void> Function(
  dynamic exception,
  StackTrace? stack, {
  String? reason,
  bool fatal,
});

Future<void> _defaultReporter(
  dynamic exception,
  StackTrace? stack, {
  String? reason,
  bool fatal = false,
}) =>
    FirebaseCrashlytics.instance.recordError(
      exception,
      stack,
      reason: reason ?? '',
      fatal: fatal,
    );

/// RPC handler for `getContacts`. The web's "Refer Friends" page calls this on
/// mount to render the device phonebook (a WebView cannot read contacts
/// itself).
///
/// Follows the same permission flow as `captureImage`: the handler requests
/// the permission itself, and on denial gives the UI a chance to show a
/// rationale sheet that guides the user to app settings (and re-checks on
/// resume). Only when the permission is still not granted does it return
/// `PERMISSION_DENIED`.
///
/// Contacts are sourced from the list persisted at referral.json (kept warm by
/// the periodic [getContacts] sync), never a fresh in-handler phonebook read;
/// on a miss the handler asks [refreshContactsFile] to populate it, then reads.
///
/// Wire shape:
/// - request:  `{}`
/// - response: `{ "contacts": [ { "name": "Akshay", "phone": "8040683308" }, ... ] }`
class GetContactsHandler implements BifrostHandler {
  GetContactsHandler({
    PermissionRequester? permissionRequester,
    PermissionDeniedHandler? onPermissionDenied,
    ErrorReporter? errorReporter,
    ContactsReader? contactsReader,
    ContactsPopulator? contactsPopulator,
  })  : _requestPermission = permissionRequester ?? _defaultRequestPermission,
        _onPermissionDenied = onPermissionDenied,
        _reportError = errorReporter ?? _defaultReporter,
        _readContacts = contactsReader ?? readReferralContactsFile,
        _populateContacts = contactsPopulator ?? refreshContactsFile;

  final PermissionRequester _requestPermission;
  final PermissionDeniedHandler? _onPermissionDenied;
  final ErrorReporter _reportError;
  final ContactsReader _readContacts;
  final ContactsPopulator _populateContacts;

  @override
  String get actionName => WebViewConstants.eventGetContacts;

  @override
  BifrostPattern get pattern => BifrostPattern.rpc;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    // ── Contacts permission gate ──
    var status = await _requestPermission(Permission.contacts);
    if (!_isPermissionGranted(status)) {
      // Give the UI a chance to show a bottom sheet and guide the user to
      // settings. If the callback resolves the permission we continue;
      // otherwise return the error.
      if (_onPermissionDenied != null) {
        MixpanelSetup.logEvent(TrackingEvents.getContactsPermissionShowingUi, {
          'status': status.name,
        });
        final resolved = await _onPermissionDenied(status);
        if (resolved) {
          // Re-check after the user returned from settings.
          status = await _requestPermission(Permission.contacts);
        }
      }

      if (!_isPermissionGranted(status)) {
        MixpanelSetup.logEvent(TrackingEvents.getContactsPermissionDenied, {
          'status': status.name,
        });
        return BifrostResult(
          error: BifrostError(
            code: BifrostErrorCodes.permissionDenied,
            message: 'Contacts permission not granted',
            details: {'permission': 'contacts', 'status': status.name},
          ),
        );
      }
    }

    try {
      // Serve the already-synced list; only populate (via the existing
      // background sync) and re-read when it hasn't been written yet.
      var contacts = await _readContacts();
      if (contacts.isEmpty) {
        await _populateContacts();
        contacts = await _readContacts();
      }
      return BifrostResult(data: {'contacts': contacts});
    } catch (e, stack) {
      MonitoringServiceHelper.logError('get_contacts_error', {
        'error': e.toString(),
        'stackTrace': stack.toString(),
      });
      _reportError(e, stack,
          reason: 'getContacts handler failed', fatal: false);
      return BifrostResult(
        error: BifrostError(
          code: BifrostErrorCodes.internalError,
          message: 'Failed to fetch contacts',
        ),
      );
    }
  }

  static bool _isPermissionGranted(PermissionStatus status) =>
      status == PermissionStatus.granted ||
      status == PermissionStatus.limited ||
      status == PermissionStatus.provisional;
}

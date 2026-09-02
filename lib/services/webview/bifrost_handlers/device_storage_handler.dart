import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/webview/bifrost_envelope.dart';
import 'package:snabbit_runner/services/webview/bifrost_error_codes.dart';
import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// RPC handler: generic device-storage bridge over SharedPreferences.
///
/// Web calls `deviceStorage({ action, key, value? })` and awaits `{ value }`:
/// - `set`    → persist `value` under `key` as a jsonEncoded string; returns `{ value: null }`.
/// - `get`    → returns `{ value }` (the jsonDecoded value, or `null` if absent).
/// - `delete` → removes `key`; returns `{ value: null }`.
///
/// One event/handler for all three so the surface stays small. jsonEncode lets
/// objects, lists, bools and numbers round-trip. A stored value that isn't
/// valid JSON is returned as-is rather than throwing.
class DeviceStorageHandler implements BifrostHandler {
  @override
  String get actionName => WebViewConstants.eventDeviceStorage;

  @override
  BifrostPattern get pattern => BifrostPattern.rpc;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) async {
    final action = data['action'];
    final key = data['key'];
    if (key is! String || key.isEmpty) {
      return _error(
        BifrostErrorCodes.invalidArgs,
        'A non-empty string `key` is required.',
      );
    }

    final prefs = GlobalState().prefs ?? await SharedPreferences.getInstance();

    switch (action) {
      case 'set':
        await prefs.setString(key, jsonEncode(data['value']));
        return const BifrostResult(data: {'value': null});

      case 'get':
        final raw = prefs.getString(key);
        dynamic value;
        if (raw != null) {
          try {
            value = jsonDecode(raw);
          } catch (e) {
            MonitoringServiceHelper.logError('device_storage_decode_failed', {
              'key': key,
              'error': e.toString(),
            });
            value = raw;
          }
        }
        return BifrostResult(data: {'value': value});

      case 'delete':
        await prefs.remove(key);
        return const BifrostResult(data: {'value': null});

      default:
        return _error(
          BifrostErrorCodes.invalidAction,
          'Unknown action "$action"; expected set | get | delete.',
        );
    }
  }

  BifrostResult _error(String code, String message) =>
      BifrostResult(error: BifrostError(code: code, message: message));
}

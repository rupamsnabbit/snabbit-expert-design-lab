import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class BcpStore {
  static const String storageKey = 'bcp_blocks_v1';

  final SharedPreferences _prefs;

  BcpStore(this._prefs);

  Future<Map<String, DateTime>> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <String, DateTime>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return <String, DateTime>{};
      final now = DateTime.now();
      final out = <String, DateTime>{};
      decoded.forEach((key, value) {
        if (key is! String) return;
        final ms = anyValueToInt(value);
        if (ms == null) return;
        final when = DateTime.fromMillisecondsSinceEpoch(ms);
        if (when.isAfter(now)) out[key] = when;
      });
      return out;
    } catch (e) {
      try {
        MonitoringServiceHelper.logError(
          'BCP_STORE_LOAD_FAILED',
          {'error': e.toString()},
        );
      } catch (_) {}
      return <String, DateTime>{};
    }
  }

  Future<void> save(Map<String, DateTime> blocks) async {
    final now = DateTime.now();
    final pruned = <String, int>{};
    blocks.forEach((key, when) {
      if (when.isAfter(now)) pruned[key] = when.millisecondsSinceEpoch;
    });
    if (pruned.isEmpty) {
      await _prefs.remove(storageKey);
      return;
    }
    await _prefs.setString(storageKey, json.encode(pruned));
  }

  Future<void> clear() async {
    await _prefs.remove(storageKey);
  }
}

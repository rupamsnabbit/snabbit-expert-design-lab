import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Durable buffer for a `safety_shield_sos` push action that arrived while the
/// [SafetyShieldAdapter] was unavailable (pre-mount, or a background isolate).
///
/// The action is persisted and drained on the next foreground, then forwarded
/// to the adapter. This is a belt-and-suspenders layer on top of the backend
/// reconciliation (`syncActiveSosState`), which remains the source of truth.
class ShieldSosPushStore {
  static const _key = 'pending_shield_sos_action';

  static Future<void> persist({required String action, required int sosId}) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode({'action': action, 'sos_id': sosId}));
    } catch (e) {
      // Best-effort only — backend reconciliation is the fallback.
      MonitoringServiceHelper.logWarning('ShieldSosPushStore: persist failed', {
        'error': e.toString(),
      });
    }
  }

  /// Returns the pending action (and clears it), or null if none.
  static Future<({String action, int sosId})?> drain() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return null;
      // Parse BEFORE removing: if jsonDecode throws on malformed JSON the key
      // remains in prefs so the next foreground can retry. Removing first would
      // silently discard the SoS action on any parse failure.
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final action = m['action'] as String?;
      final sosId = m['sos_id'];
      if (action == null || sosId is! int) return null;
      await p.remove(_key);
      return (action: action, sosId: sosId);
    } catch (e) {
      MonitoringServiceHelper.logWarning('ShieldSosPushStore: drain failed', {
        'error': e.toString(),
      });
      return null;
    }
  }
}

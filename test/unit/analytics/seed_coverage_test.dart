import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static coverage check: every event name emitted from Dart through the
/// catalog-routed facades (MixpanelSetup / ClevertapSetup / wrappers) must
/// have a destination in `AnalyticsRoutesConfig.SEED`. Catalog misses fire
/// `onUnrouted` (drop + Crashlytics) under strict `default = emptySet()`;
/// this test catches the gap before runtime.
///
/// Webview events (`KmpWebAnalyticsSink`) are NOT covered — they bypass
/// the catalog via explicit `targets`, validated separately by the
/// "unknown explicit targets" warning in `AnalyticsTrackerImpl`.
void main() {
  test('every emitted Dart event has a SEED entry', () {
    final emitted = _collectEmittedEvents();
    final seedKeys = _parseSeedKeys();

    final missing = emitted.difference(seedKeys).toList()..sort();

    expect(
      missing,
      isEmpty,
      reason: 'These events are fired from Dart but missing from '
          'AnalyticsRoutesConfig.SEED — they will be dropped under strict '
          'routing. Add them to the SEED table:\n${missing.join("\n")}',
    );
  });
}

Set<String> _collectEmittedEvents() {
  final constMap = _parseTrackingEventsConstants();
  final firingCallers = [
    r'MixpanelSetup\.logEvent',
    r'ClevertapSetup\.logEvent',
    r'OnboardingAnalytics\.logEvent',
    r'_trackShieldEvent',
    r'\.logShieldEvent',
    r'TrackingCommon\.logMixpanelEvent',
    r'JobLifecycleAnalytics\.logEvent',
  ];
  final firingPattern = RegExp(
    '(?:${firingCallers.join("|")})'
    r'''\(\s*((?:TrackingEvents\.\w+)|(?:'[^']+')|(?:"[^"]+"))''',
  );

  final emitted = <String>{};
  final libDir = Directory('lib');
  for (final file in libDir.listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    if (file.path.endsWith('lib/utils/tracking_events.dart')) continue;
    final src = file.readAsStringSync();
    for (final m in firingPattern.allMatches(src)) {
      final arg = m.group(1)!.trim();
      if (arg.startsWith('TrackingEvents.')) {
        final c = arg.substring('TrackingEvents.'.length);
        final v = constMap[c];
        if (v != null) emitted.add(v);
      } else {
        emitted.add(arg.substring(1, arg.length - 1));
      }
    }
  }

  // expert_shield_native_* events are fired via a lookup map
  // (shield_event_handler._nativeToProductEvent) — variable arg, not a
  // string literal, so the regex above misses them. Add explicitly.
  for (final entry in constMap.entries) {
    if (entry.key.startsWith('expertShieldNative')) emitted.add(entry.value);
  }

  return emitted;
}

Map<String, String> _parseTrackingEventsConstants() {
  final src = File('lib/utils/tracking_events.dart').readAsStringSync();
  // Match: static const String NAME = ...; (multi-line, concat literals).
  final declPattern =
      RegExp(r'static\s+const\s+String\s+(\w+)\s*=\s*(.*?);', dotAll: true);
  final literalPattern = RegExp(r'''"([^"]*)"|'([^']*)' ''');
  final out = <String, String>{};
  for (final m in declPattern.allMatches(src)) {
    final name = m.group(1)!;
    final rhs = m.group(2)!;
    final parts =
        literalPattern.allMatches(rhs).map((lm) => lm.group(1) ?? lm.group(2)!);
    final value = parts.join();
    if (value.isNotEmpty) out[name] = value;
  }
  return out;
}

Set<String> _parseSeedKeys() {
  final src = File(
    'shared/src/commonMain/kotlin/com/snabbit/runner/shared/core/analytics/AnalyticsRoutesConfig.kt',
  ).readAsStringSync();
  final keyPattern = RegExp(r'"([^"]+)"\s+to\s+setOf\(');
  return keyPattern.allMatches(src).map((m) => m.group(1)!).toSet();
}

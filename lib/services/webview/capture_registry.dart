import 'dart:async';
import 'dart:io';

import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// In-memory registry of captured images, keyed by opaque tokens with
/// automatic TTL-based expiry.
///
/// Captures are registered after the camera writes a file to the
/// dedicated temp directory, and resolved by [CapturePathHandler] when
/// the WebView fetches the image URL. Tokens expire after [_defaultTtl]
/// and a periodic sweep deletes stale files from disk.
///
/// Thread-safety: Dart is single-threaded (single isolate); no mutex
/// needed. The sweep timer fires on the event loop between awaits.
class CaptureRegistry {
  CaptureRegistry._();

  static final CaptureRegistry instance = CaptureRegistry._();

  static const Duration _defaultTtl = Duration(minutes: 15);
  static const Duration _sweepInterval = Duration(minutes: 5);

  /// Max servable capture size (10 MB). Single source of truth shared by
  /// the capture-time guard ([CaptureImageHandler]) and the serve-time
  /// guard ([CapturePathHandler]) so the two limits can't drift apart.
  /// A front-camera selfie is typically 1–3 MB; beyond this we can't load
  /// it into a [WebResourceResponse] without risking OOM on budget devices.
  static const int maxCaptureSizeBytes = 10 * 1024 * 1024;

  final Map<String, _CaptureEntry> _entries = {};
  Timer? _sweepTimer;

  /// Starts the periodic sweep timer if it isn't already running.
  void _ensureSweepTimer() {
    _sweepTimer ??= Timer.periodic(_sweepInterval, (_) => _sweep());
  }

  /// Cancels the sweep timer when there are no entries left to manage.
  void _cancelSweepTimerIfIdle() {
    if (_entries.isEmpty) {
      _sweepTimer?.cancel();
      _sweepTimer = null;
    }
  }

  /// Registers [file] and returns an opaque token the WebView can use to
  /// fetch the image via the asset-loader URL.
  ///
  /// If [token] is provided it is used as-is; otherwise one is generated
  /// from the current microsecond timestamp.
  String register(
    File file, {
    String? token,
    Duration ttl = _defaultTtl,
  }) {
    final key = token ?? DateTime.now().microsecondsSinceEpoch.toString();
    _entries[key] = _CaptureEntry(file, DateTime.now().add(ttl));
    _ensureSweepTimer();
    return key;
  }

  /// Returns the [File] for [token] if it is still valid, or `null` if
  /// the token is unknown or has expired. Expired entries are evicted
  /// eagerly (file deleted, entry removed).
  File? resolve(String token) {
    final entry = _entries[token];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(token);
      _deleteFile(entry.file);
      return null;
    }
    return entry.file;
  }

  /// Explicitly evicts [token] — deletes the backing file and removes
  /// the entry. No-op if the token is unknown.
  Future<void> evict(String token) async {
    final entry = _entries.remove(token);
    if (entry != null) {
      await _deleteFile(entry.file);
    }
    _cancelSweepTimerIfIdle();
  }

  /// Clears the entire capture [directory]. Intended to run **once at
  /// startup**: on a fresh process the in-memory registry is empty and no
  /// capture is in flight, so every file in `captures/` is an orphan from a
  /// prior session (a process kill can leave files the in-session TTL never
  /// evicted). Clearing wholesale is simpler and more complete than an age
  /// scan — no orphan lingers — and avoids stat-ing every file. The directory
  /// is recreated lazily on the next capture.
  ///
  /// Must NOT be called mid-session: it would delete files backing live
  /// registry entries.
  static Future<void> sweepStale(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _sweep() {
    final now = DateTime.now();
    final expired = _entries.entries
        .where((e) => now.isAfter(e.value.expiresAt))
        .map((e) => e.key)
        .toList();

    for (final key in expired) {
      final entry = _entries.remove(key);
      if (entry != null) _deleteFile(entry.file);
    }

    if (expired.isNotEmpty) {
      MonitoringServiceHelper.logInfo(
        'capture_registry_sweep',
        {
          'evictedCount': expired.length,
          'remainingCount': _entries.length,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }

    _cancelSweepTimerIfIdle();
  }

  static Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup — the file may already be gone.
    }
  }
}

class _CaptureEntry {
  _CaptureEntry(this.file, this.expiresAt);

  final File file;
  final DateTime expiresAt;
}

import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'snabbit_shield_config.dart';
import 'snabbit_shield_database.dart';
import 'shield_http.dart';

class ShieldUploadQueue {
  final ShieldDatabase _db;
  StreamSubscription? _connectivitySub;
  bool _processing = false;
  // Set when processQueue() is called while already processing so the newly
  // enqueued row is not missed — re-triggers a pass after the current one ends.
  bool _pendingRetrigger = false;
  bool _wasInternetConnected = false;

  static const _table = 'snabbit_shield_uploads';
  static const _maxPendingEntries = 20;
  static const _maxAgeDays = 7;
  static const _httpConflict = 409;

  ShieldUploadQueue({required ShieldDatabase db}) : _db = db;

  void start() async {
    _wasInternetConnected = true;

    final initial = await Connectivity().checkConnectivity();
    _wasInternetConnected = initial.any((r) => r != ConnectivityResult.none);

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && !_wasInternetConnected) {
        processQueue(source: "connectivity_listener");
      }
      _wasInternetConnected = isConnected;
    });
    processQueue(source: "upload_queue_start"); // flush any entries pending from before the app restarted
  }

  void stop() => _connectivitySub?.cancel();

  /// Insert encrypted audio + metadata into DB, enforce caps, then trigger
  /// the 3-step upload (presigned URL → S3 PUT → confirm) in the background.
  Future<void> enqueue({
    required int bookingId,
    required int timestamp,
    required Uint8List encryptedAudioBytes,
    required ShieldEncryptionMetadata encryptionMetadata,
    required int durationSeconds,
    bool isSos = false,
  }) async {
    await _db.insert(_table, {
      'booking_id': bookingId,
      'timestamp': timestamp,
      'encrypted_audio_bytes': encryptedAudioBytes,
      'encryption_metadata_json': jsonEncode(encryptionMetadata.toJson()),
      'duration_seconds': durationSeconds,
      'is_sos': isSos ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _enforceQueueCap();
    // Fire-and-forget: don't block the caller while uploading
    unawaited(processQueue(source: "enqueue record persist"));
  }

  /// Process all pending entries oldest-first via the 3-step upload flow:
  /// 1. Get presigned S3 URL
  /// 2. PUT encrypted bytes to S3
  /// 3. Confirm upload with encryption metadata
  ///
  /// Guarded against concurrent execution.
  /// Per-row bounded retries before a clip is dropped (avoids both
  /// head-of-line blocking and infinite retry / instant data-loss on 4xx).
  static const _maxRetries = 5;

  Future<void> processQueue({String? source}) async {
    if (_processing) {
      // A run is already in progress. Signal it to retrigger when done so
      // the row we just enqueued isn't left waiting for the next connectivity
      // change (the race: enqueue fires unawaited(processQueue) AFTER the
      // in-flight _db.query snapshot was already taken).
      _pendingRetrigger = true;
      return;
    }
    _processing = true;
    _pendingRetrigger = false;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Only rows whose backoff window has elapsed; oldest-first.
      final rows = await _db.query(
        _table,
        where: 'next_attempt_at <= ?',
        whereArgs: [now],
        orderBy: 'created_at ASC',
      );
      if (rows.isEmpty) return;

      for (final row in rows) {
        // ── Parse row ──────────────────────────────────────────────────────
        // Separated from the HTTP try so a corrupt/unreadable row is DROPPED
        // and the loop continues — never break-ing the queue on bad data.
        int id;
        int bookingId;
        int timestamp;
        Uint8List encryptedBytes;
        ShieldEncryptionMetadata metadata;
        int duration;
        bool isSos;
        int retryCount;
        try {
          id = row['id'] as int;
          bookingId = row['booking_id'] as int;
          timestamp = row['timestamp'] as int;
          encryptedBytes = row['encrypted_audio_bytes'] as Uint8List;
          final metadataJson =
              jsonDecode(row['encryption_metadata_json'] as String);
          metadata = ShieldEncryptionMetadata.fromJson(
              metadataJson as Map<String, dynamic>);
          duration = row['duration_seconds'] as int;
          isSos = (row['is_sos'] as int) == 1;
          retryCount = (row['retry_count'] as int?) ?? 0;
        } catch (e, st) {
          // Row is corrupt or has an unreadable field. Drop it so it cannot
          // permanently stall the queue on every subsequent processQueue pass.
          final corruptId = row['id'];
          if (corruptId != null) {
            await _db.delete(_table, where: 'id = ?', whereArgs: [corruptId]);
          }
          MonitoringServiceHelper.logError(
            'Snabbit Shield upload row corrupt — dropping',
            {
              'api': 'parse_row',
              'row_id': corruptId,
              'error': e.toString(),
              'reason': 'parse_failed',
              if (source != null) 'flow_source': source,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          continue;
        }

        // ── HTTP upload (3-step) ───────────────────────────────────────────
        try {
          // Step 1: Get presigned URL.
          final urlResult = await ShieldHttp.getPresignedUrl(
            bookingId: bookingId,
            timestamp: timestamp,
            isSos: isSos,
          );
          if (!urlResult.isSuccess) {
            if (urlResult.statusCode == _httpConflict) {
              // Duplicate — the server already has this recording. Success.
              await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
              continue;
            }
            // Any other non-2xx (incl. 400): bounded retry, then drop with
            // a status-coded error. Advance to the next row (no queue halt).
            await _retryOrDrop(
                id, retryCount, 'get_presigned_url', urlResult.statusCode,
                bookingId, isSos);
            continue;
          }

          // Step 2: PUT to S3 using the content-type the URL was signed for.
          final s3Result = await ShieldHttp.uploadToS3(
            urlResult.data!.presignedUrl,
            encryptedBytes,
            _contentTypeFor(urlResult.data!),
          );
          if (!s3Result.success) {
            // Transient failure (expired URL / network / S3 error) — bounded
            // retry with backoff; drop after _maxRetries so a persistently
            // failing row cannot retry forever (infinite-retry bypass bug).
            await _retryOrDrop(
                id, retryCount, 'upload_to_s3', s3Result.statusCode, bookingId, isSos);
            continue;
          }

          // Step 3: Confirm.
          final confirmResult = await ShieldHttp.confirmUpload(
            bookingId: bookingId,
            timestamp: timestamp,
            s3Key: urlResult.data!.s3Key,
            durationSeconds: duration,
            encryptionMetadata: metadata,
            isSos: isSos,
            isCompressed: metadata.isCompressed,
          );
          if (confirmResult.isSuccess || confirmResult.statusCode == 409) {
            await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
            MixpanelSetup.logEvent(TrackingEvents.expertShieldUploadSuccess, {
              'job_id': bookingId,
              'is_sos': isSos,
              'retry_count': retryCount,
              if (source != null) 'flow_source': source,
              'clip_size_bytes': encryptedBytes.length,
            });
            continue;
          }
          await _retryOrDrop(
              id, retryCount, 'confirm_upload', confirmResult.statusCode,
              bookingId, isSos);
          continue;
        } catch (e) {
          // Increment retry_count so a persistently broken row eventually hits
          // _maxRetries and is dropped. Without this, exception rows never
          // advance retry_count and loop forever across every processQueue pass.
          MonitoringServiceHelper.logWarning(
            'shield_upload_row_exception',
            {'id': id, 'booking_id': bookingId, 'retry_count': retryCount, if (source != null) 'flow_source': source, 'error': '$e'},
          );
          await _retryOrDrop(id, retryCount, 'row_exception', null, bookingId, isSos);
          continue;
        }
      }
    } finally {
      _processing = false;
      // If a new row arrived while we were processing, run one more pass now
      // rather than waiting for the next connectivity event.
      if (_pendingRetrigger) {
        _pendingRetrigger = false;
        unawaited(processQueue(source: "pending_retrigger"));
      }
    }
  }

  /// Content-type the presigned URL was signed for (S3 enforces it on PUT).
  String _contentTypeFor(PresignedUrlResponse resp) {
    if (resp.allowedContentTypes.isNotEmpty) return resp.allowedContentTypes.first;
    return 'audio/mp4';
  }

  /// Increment retry; reschedule with backoff, or drop (with a status-coded
  /// error log) once the retry cap is exhausted.
  Future<void> _retryOrDrop(int id, int retryCount, String api, int? statusCode,
      int bookingId, bool isSos) async {
    final next = retryCount + 1;
    if (next >= _maxRetries) {
      await MonitoringServiceHelper.logError(
        'Snabbit Shield upload dropped (max retries)',
        {
          'api': api,
          'status_code': statusCode,
          'job_id': bookingId,
          'is_sos': isSos,
          'retry_count': next,
          'reason': 'max_retries_exhausted',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      MixpanelSetup.logEvent(TrackingEvents.expertShieldUploadDropped, {
        'job_id': bookingId,
        'is_sos': isSos,
        'retry_count': next,
        'failed_step': api,
        'status_code': statusCode,
        'reason': 'clip_max_retries_exceeded',
      });
      await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
      return;
    }
    await _rescheduleRow(id, retryCount);
  }

  Future<void> _rescheduleRow(int id, int retryCount) async {
    final next = retryCount + 1;
    await _db.update(
      _table,
      {
        'retry_count': next,
        'next_attempt_at':
            DateTime.now().millisecondsSinceEpoch + _backoffMs(next),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Exponential backoff: 5s, 10s, 20s, 40s … capped at 30 min.
  int _backoffMs(int attempt) {
    const baseMs = 5000;
    const capMs = 30 * 60 * 1000;
    final ms = baseMs * (1 << (attempt - 1));
    return ms > capMs ? capMs : ms;
  }

  /// FR-22: Cap at 20 pending entries or 7 days, whichever is reached first.
  ///
  /// SoS clips are prioritised over normal clips: when the cap is hit,
  /// normal clips are dropped before SoS clips regardless of arrival order.
  /// Within each group, newest clips survive (oldest are dropped first).
  Future<void> _enforceQueueCap() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _maxAgeDays))
        .millisecondsSinceEpoch;
    await _db.delete(_table, where: 'created_at < ?', whereArgs: [cutoff]);

    // Fetch IDs only (skip BLOB columns — avoids deserialising ~MB of audio
    // data just to enforce a count cap).
    // Order: SoS clips first (is_sos DESC), newest-first within each group.
    // Rows beyond the cap (skip(20)) are the oldest normal clips — SoS clips
    // stay at the front and survive the cut.
    final rows = await _db.query(
      _table,
      columns: ['id'],
      orderBy: 'is_sos DESC, created_at DESC',
    );
    if (rows.length > _maxPendingEntries) {
      final excessIds = rows
          .skip(_maxPendingEntries)
          .map((r) => r['id'])
          .whereType<Object>()
          .toList();
      if (excessIds.isNotEmpty) {
        await _db.delete(
          _table,
          where: 'id IN (${List.filled(excessIds.length, '?').join(',')})',
          whereArgs: excessIds,
        );
      }
    }
  }

  /// FR-23: On logout, delete all pending queue entries.
  Future<void> clearAll() async {
    await _db.delete(_table);
  }
}

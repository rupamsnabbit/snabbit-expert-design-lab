import 'dart:convert';

/// Structured error surfaced across the bifrost. See proposal §2.9.
class BifrostError {
  const BifrostError({
    required this.code,
    required this.message,
    this.details,
    this.retryable = false,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final bool retryable;

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
        if (retryable) 'retryable': true,
      };

  static BifrostError? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final code = raw['code'];
    final message = raw['message'];
    if (code is! String || code.isEmpty) return null;
    if (message is! String) return null;
    final details = raw['details'];
    final retryable = raw['retryable'];
    return BifrostError(
      code: code,
      message: message,
      details: details is Map<String, dynamic> ? details : null,
      retryable: retryable == true,
    );
  }
}

/// Wire-format envelope for every message exchanged with the web page.
/// See proposal §2.1.
class BifrostEnvelope {
  const BifrostEnvelope({
    required this.event,
    required this.data,
    this.requestId,
    this.error,
  });

  final String event;
  final Map<String, dynamic> data;
  final String? requestId;
  final BifrostError? error;

  /// Parses a raw JSON string. Returns null for anything that isn't a
  /// syntactically valid envelope: malformed JSON, wrong top-level type,
  /// missing/blank `event`, or `data` / `requestId` of the wrong type.
  ///
  /// Lenient on `data`: a missing `data` is treated as an empty map so
  /// callers (e.g. `backPressed`) can omit it.
  static BifrostEnvelope? tryParse(String raw) {
    if (raw.isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final event = decoded['event'];
    if (event is! String || event.isEmpty) return null;

    final rawData = decoded['data'];
    Map<String, dynamic> data;
    if (rawData == null) {
      data = const {};
    } else if (rawData is Map<String, dynamic>) {
      data = rawData;
    } else {
      return null;
    }

    final rawRequestId = decoded['requestId'];
    String? requestId;
    if (rawRequestId != null) {
      if (rawRequestId is! String || rawRequestId.isEmpty) return null;
      requestId = rawRequestId;
    }

    return BifrostEnvelope(
      event: event,
      data: data,
      requestId: requestId,
      error: BifrostError.tryParse(decoded['error']),
    );
  }

  Map<String, dynamic> toJson() => {
        'event': event,
        if (data.isNotEmpty) 'data': data,
        if (requestId != null) 'requestId': requestId,
        if (error != null) 'error': error!.toJson(),
      };

  String encode() => jsonEncode(toJson());
}

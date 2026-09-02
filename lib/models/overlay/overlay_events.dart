class CTAEvent {
  final String actionId;
  final Map<String, dynamic> data;

  CTAEvent({required this.actionId, this.data = const {}});

  factory CTAEvent.fromMap(Map<String, dynamic> map) => CTAEvent(
        actionId: map['actionId'] ?? '',
        data: map['data'] ?? {},
      );
}

class DismissEvent {
  final String reason;

  DismissEvent({required this.reason});

  factory DismissEvent.fromMap(Map<String, dynamic> map) => DismissEvent(
        reason: map['reason'] ?? 'unknown',
      );
}

class OverlayError {
  final String code;
  final String message;
  final String? stackTrace;

  OverlayError({required this.code, required this.message, this.stackTrace});

  factory OverlayError.fromMap(Map<String, dynamic> map) => OverlayError(
        code: map['code'] ?? '',
        message: map['message'] ?? '',
        stackTrace: map['stackTrace'],
      );
}

class LifecycleEvent {
  final String event;
  final Map<String, dynamic> payload;

  LifecycleEvent({required this.event, this.payload = const {}});

  factory LifecycleEvent.fromMap(Map<dynamic, dynamic> map) => LifecycleEvent(
        event: map['event'] ?? '',
        payload: Map<String, dynamic>.from(map)..remove('event'),
      );
}

import 'dart:convert';

class IotDiagnosticEvent {
  final int id;
  final String eventName;
  final Map<String, dynamic> eventData;
  final int createdAt;
  final bool processed;

  IotDiagnosticEvent({
    this.id = 0,
    required this.eventName,
    required this.eventData,
    required this.createdAt,
    this.processed = false,
  });

  factory IotDiagnosticEvent.fromMap(Map<String, dynamic> map) {
    return IotDiagnosticEvent(
      id: map['id'] as int,
      eventName: map['event_name'] as String,
      eventData: jsonDecode(map['event_data'] as String) as Map<String, dynamic>,
      createdAt: map['created_at'] as int,
      processed: map['processed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'event_name': eventName,
      'event_data': jsonEncode(eventData),
      'created_at': createdAt,
      'processed': processed,
    };
  }
}

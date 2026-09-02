class DeviceStatusData {
  final String? deviceId;
  final StatusCheck? statusCheck;

  DeviceStatusData({
    this.deviceId,
    this.statusCheck,
  });

  factory DeviceStatusData.fromJson(Map<String, dynamic> json) {
    return DeviceStatusData(
      deviceId: json['device_id'],
      statusCheck: json['status_check'] != null
          ? StatusCheck.fromJson(json['status_check'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'status_check': statusCheck?.toJson(),
    };
  }
}

class StatusCheck {
  final bool? camera;
  final bool? location;
  final bool? speaker;
  final bool? vibration;

  StatusCheck({
    this.camera,
    this.location,
    this.speaker,
    this.vibration,
  });

  factory StatusCheck.fromJson(Map<String, dynamic> json) {
    return StatusCheck(
      camera: json['camera'],
      location: json['location'],
      speaker: json['speaker'],
      vibration: json['vibration'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'camera': camera,
      'location': location,
      'speaker': speaker,
      'vibration': vibration,
    };
  }
}

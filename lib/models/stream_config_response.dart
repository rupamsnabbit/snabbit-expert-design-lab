class StreamConfigResponse {
  final String streamApiKey;
  final String userType;

  StreamConfigResponse({
    required this.streamApiKey,
    required this.userType,
  });

  factory StreamConfigResponse.fromJson(Map<String, dynamic> json) {
    return StreamConfigResponse(
      streamApiKey: json['stream_api_key'] as String? ?? '',
      userType: json['user_type'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stream_api_key': streamApiKey,
      'user_type': userType,
    };
  }
}
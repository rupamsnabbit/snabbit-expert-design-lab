import 'package:comm_stream/comm_stream.dart';

class ChatInfo {
  final String? token;
  final String? channelId;
  final String? channelType;
  final String? callId;
  final int unreadCount;
  final List<QuickResponse> quickResponses;

  ChatInfo({
    this.token,
    this.channelId,
    this.channelType,
    this.callId,
    this.unreadCount = 0,
    this.quickResponses = const [],
  });

  /// Check if chat info has valid required fields
  bool get isValid => token != null && token!.isNotEmpty;

  factory ChatInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ChatInfo();
    }

    List<QuickResponse> quickResponses = [];
    if (json['quick_response'] != null) {
      quickResponses = (json['quick_response'] as List)
          .map((item) => QuickResponse.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return ChatInfo(
      token: json['token'] as String?,
      channelId: json['channel_id'] as String?,
      channelType: json['channel_type'] as String?,
      callId: json['call_id'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      quickResponses: quickResponses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (token != null) 'token': token,
      if (channelId != null) 'channel_id': channelId,
      if (channelType != null) 'channel_type': channelType,
      if (callId != null) 'call_id': callId,
      'unread_count': unreadCount,
      'quick_response': quickResponses.map((qr) => qr.toJson()).toList(),
    };
  }
}

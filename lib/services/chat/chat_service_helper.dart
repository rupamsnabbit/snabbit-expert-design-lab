import 'package:comm_stream/comm_stream.dart';
import 'package:snabbit_runner/services/server_requests/stream_http.dart';

import '../../models/chat_info.dart';
import '../../models/stream_config_response.dart';

/// Helper class to initialize Stream chat service using embedded chat_info
class ChatServiceHelper {
  /// Initialize chat service using ChatInfo object
  ///
  /// Returns the initialized StreamChatServiceImpl, or null if initialization fails.
  ///
  /// [chatInfo] - The ChatInfo object parsed from backend response
  /// [chatUser] - The ChatUser to use for initialization
  /// [streamApiKey] - The Stream API key (from RemoteConfig)
  static Future<StreamChatServiceImpl?> initializeChatService({
    required ChatInfo chatInfo,
    required ChatUser chatUser,
    required String streamApiKey,
  }) async {
    try {
      if (streamApiKey.isEmpty || !chatInfo.isValid) {
        return null;
      }

      // Create Stream config
      final streamConfig = StreamConfig(apiKey: streamApiKey);

      // Create chat service
      final chatService = StreamChatServiceImpl();

      // Initialize with token from ChatInfo
      await chatService.initialize(chatUser, streamConfig, chatInfo.token!);

      return chatService;
    } catch (e) {
      return null;
    }
  }

  /// Get Stream config from the dedicated stream API endpoint
  static Future<StreamConfigResponse?> getStreamConfig() async {
    try {
      final response = await StreamHttp.getStreamApiKey();
      if (response != null && response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return StreamConfigResponse.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get Stream API key from the dedicated stream API endpoint
  static Future<String> getStreamApiKey() async {
    final config = await getStreamConfig();
    return config?.streamApiKey ?? '';
  }

  /// Check if a Firebase message is from Stream Chat
  /// Stream Chat messages have specific data fields
  static bool isStreamChatMessage(Map<String, dynamic> data) {
    return data.containsKey('sender') && 
           data.containsKey('channel_id') &&
           data.containsKey('type') &&
           data['type'] == 'message.new';
  }

  /// Parse Stream Chat notification data
  static ({String senderName, String messageText, String channelId})? 
      parseStreamMessage(Map<String, dynamic> data) {
    try {
      final senderName = data['sender'] as String? ?? 'Unknown';
      final messageText = data['message'] as String? ?? '';
      final channelId = data['channel_id'] as String? ?? '';
      
      return (
        senderName: senderName,
        messageText: messageText,
        channelId: channelId,
      );
    } catch (e) {
      return null;
    }
  }
}


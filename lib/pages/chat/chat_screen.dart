import 'package:comm_stream/comm_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../models/chat_info.dart';
import '../../providers/language_provider.dart';
import '../../providers/runner_rt_data.dart';
import '../../providers/user_profile.dart';
import '../../services/chat/chat_service_helper.dart';
import '../../services/clevertap.dart';
import '../../utils/colors.dart';
import '../../utils/tracking_events.dart';

/// Screen for displaying chat with a customer
/// Handles all chat initialization
class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  /// Source of navigation: 'button' or 'notification'
  final String source;

  const ChatScreen({super.key, this.source = 'button'});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  StreamChatServiceImpl? _chatService;
  ChatInfo? _chatInfo;
  bool _isLoading = true;
  String? _errorMessage;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  bool _initialized = false;
  ValueNotifier<List<QuickResponse>>? quickResponsesNotifier;

  /// Get widget data from RunnerRtDataProvider
  Map<String, dynamic>? get widgetData => runnerRtDataProvider.widgetInfo?.data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);

      // Track chat screen opened
      final jobId = runnerRtDataProvider.jobId?.toString() ??
          widgetData?['job_id']?.toString();
      ClevertapSetup.logEvent(TrackingEvents.chatScreenOpened, {
        'source': widget.source,
        'job_id': jobId,
      });

      _initializeChat();
    } else {
      // Update quick responses when provider data changes
      _updateQuickResponses();
    }
  }

  @override
  void dispose() {
    // Track chat screen closed
    ClevertapSetup.logEvent(TrackingEvents.chatScreenClosed, {
      'source': widget.source,
    });

    // Dispose chat service to close WebSocket connection
    _chatService?.dispose();
    _chatService = null;

    quickResponsesNotifier?.dispose();
    super.dispose();
  }

  void _updateQuickResponses() {
    final chatInfoJson = widgetData?['chat_info'];
    if (chatInfoJson != null) {
      final chatInfo = ChatInfo.fromJson(chatInfoJson as Map<String, dynamic>);
      quickResponsesNotifier?.value = chatInfo.quickResponses;
    }
  }

  Future<void> _initializeChat() async {
    try {
      // Parse ChatInfo from widgetData
      final chatInfoJson = widgetData?['chat_info'];
      if (chatInfoJson == null) {
        setState(() {
          _errorMessage = languageProvider.getMessage(
              'chat_service_not_available',
              'Chat service is not available for this job');
          _isLoading = false;
        });
        return;
      }

      final chatInfo = ChatInfo.fromJson(chatInfoJson as Map<String, dynamic>);

      // Get runner data
      final userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      final runner = userProfileProvider.user;
      if (runner == null) {
        setState(() {
          _errorMessage = languageProvider.getMessage(
              'runner_not_found', 'Runner not found');
          _isLoading = false;
        });
        return;
      }

      // Get Stream API key
      final streamApiKey = await ChatServiceHelper.getStreamApiKey();
      if (streamApiKey.isEmpty) {
        setState(() {
          _errorMessage = languageProvider.getMessage(
              'chat_service_not_configured', 'Chat service is not configured');
          _isLoading = false;
        });
        return;
      }

      // Create ChatUser for runner
      final chatUser = ChatUser(
        id: 'runner_${runner.id}',
        name: runner.name ?? 'Runner',
        imageUrl: runner.publicPic,
        email: null,
        phoneNumber: '${runner.countryCode}${runner.phoneNumber}',
      );

      // Initialize chat service using shared helper
      final chatService = await ChatServiceHelper.initializeChatService(
        chatInfo: chatInfo,
        chatUser: chatUser,
        streamApiKey: streamApiKey,
      );
      if (chatService == null) {
        setState(() {
          _errorMessage = languageProvider.getMessage(
              'failed_to_initialize_chat', 'Failed to initialize chat service');
          _isLoading = false;
        });
        return;
      }

      // Get job ID and open chat
      if (!mounted) return;
      final jobId = runnerRtDataProvider.jobId?.toString() ??
          widgetData?['job_id']?.toString();
      if (jobId == null) {
        setState(() {
          _errorMessage = languageProvider.getMessage(
              'job_id_not_found', 'Job ID not found');
          _isLoading = false;
        });
        return;
      }

      final customerId = widgetData?["customer_id"]?.toString();
      final customerChatId = customerId != null ? 'customer_$customerId' : null;

      // Open booking chat
      await chatService.openBookingChatWithMembers(
        bookingId: jobId,
        otherUserId: customerChatId,
      );

      if (!mounted) return;
      // Initialize quick responses notifier
      quickResponsesNotifier = ValueNotifier<List<QuickResponse>>(
        chatInfo.quickResponses,
      );

      // Track chat initialization success
      ClevertapSetup.logEvent(TrackingEvents.chatInitSuccess, {
        'source': widget.source,
        'job_id': jobId,
        'customer_id': customerId,
        'has_quick_responses': chatInfo.quickResponses.isNotEmpty,
      });

      setState(() {
        _chatService = chatService;
        _chatInfo = chatInfo;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      // Track chat initialization failure
      final jobId = runnerRtDataProvider.jobId?.toString() ??
          widgetData?['job_id']?.toString();
      ClevertapSetup.logEvent(TrackingEvents.chatInitFailed, {
        'source': widget.source,
        'job_id': jobId,
        'error': e.toString(),
      });

      setState(() {
        _errorMessage = languageProvider.getMessage(
            'failed_to_open_chat', 'Unable to open chat. Please try again.');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(languageProvider.getMessage('chat', 'Chat')),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(languageProvider.getMessage('chat', 'Chat')),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48.sp,
                  color: AppColors.n60,
                ),
                SizedBox(height: 16.h),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.n60,
                      ),
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child:
                      Text(languageProvider.getMessage('go_back', 'Go Back')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Get customer details from widgetData
    final customerName = widgetData?["customer_name"] ?? "Customer";
    final customerId = widgetData?["customer_id"]?.toString();
    final customerPhone = widgetData?["customer_ph_no"]?.toString();
    final customerChatId = customerId != null ? 'customer_$customerId' : null;
    final callId = _chatInfo?.callId;

    // Get runner's language preference for translation
    final userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final languagePreference = userProfileProvider.user?.languagePreference;

    // Build chat screen using the buildChatScreen method
    final chatService = _chatService;
    if (chatService == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(languageProvider.getMessage('chat', 'Chat')),
        ),
        body: Center(
          child: Text(languageProvider.getMessage('chat_service_not_available',
              'Chat service is not available for this job')),
        ),
      );
    }

    return chatService.buildChatScreen(
      otherUserName: customerName,
      otherUserAvatarUrl: null,
      otherUserPhoneNumber: customerPhone,
      callId: callId,
      otherUserId: customerChatId,
      userLanguagePreference: languagePreference,
      enableLocationSharing: false,
      quickResponsesNotifier: quickResponsesNotifier,
      onCallClicked: () {
        final jobId = runnerRtDataProvider.jobId?.toString() ??
            widgetData?['job_id']?.toString();
        
        ClevertapSetup.logEvent(TrackingEvents.customerInfoCallCtaClick, {
          'customer_id': customerId,
          'job_id': jobId,
          'expert_id': userProfileProvider.user?.id?.toString(),
        });
      },
    );
  }
}

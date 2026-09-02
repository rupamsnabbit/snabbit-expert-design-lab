import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat_info.dart';
import '../../pages/chat/chat_screen.dart';
import '../../providers/language_provider.dart';
import '../../providers/runner_rt_data.dart';
import '../../providers/user_profile.dart';
import '../../services/clevertap.dart';
import '../../services/globals.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import '../../utils/tracking_events.dart';
import '../common_widgets/sweeping_shine.dart';

/// Key used to persist whether chat has been seen at least once
const String _chatSeenAtLeastOnceKey = 'chat_seen_at_least_once';

typedef _CustomerDetailsData = ({
  String? customerName,
  String? customerPhNo,
  String? customerId,
  String? expertId,
  int? jobId,
  bool hasChatInfo,
  int unreadCount,
});

class CustomerDetails extends StatefulWidget {
  // Optional per-screen tap hooks. Lets each parent fire its own
  // analytics event (e.g. arrival_call_customer_cta_click on the
  // arrival timer screen) without conflating events across the
  // arrival-timer / on-the-job screens that both embed this widget.
  final VoidCallback? onCallTap;
  final VoidCallback? onChatTap;
  const CustomerDetails({super.key, this.onCallTap, this.onChatTap});

  @override
  State<CustomerDetails> createState() => _CustomerDetailsState();
}

class _CustomerDetailsState extends State<CustomerDetails> {
  bool _hasChatBeenSeenBefore = false;

  @override
  void initState() {
    super.initState();
    _loadChatSeenStatus();
  }

  /// Load the persisted chat seen status from SharedPreferences
  Future<void> _loadChatSeenStatus() async {
    final prefs = GlobalState().prefs;
    if (prefs != null) {
      final persistedChatSeenValue = prefs.getBool(_chatSeenAtLeastOnceKey);

      if (persistedChatSeenValue == null) {
        // Key was never set — this is the first run after this feature was deployed.
        // Default to true so existing users who had chat before see the disabled button.
        await prefs.setBool(_chatSeenAtLeastOnceKey, true);
        if (mounted) {
          setState(() {
            _hasChatBeenSeenBefore = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasChatBeenSeenBefore = persistedChatSeenValue;
          });
        }
      }
    }
  }

  /// Persist that chat has been seen at least once
  Future<void> _markChatAsSeen() async {
    final prefs = GlobalState().prefs;
    if (prefs != null && !_hasChatBeenSeenBefore) {
      await prefs.setBool(_chatSeenAtLeastOnceKey, true);
      if (mounted) {
        setState(() {
          _hasChatBeenSeenBefore = true;
        });
      }
    }
  }

  Future<void> _launchDialer(String phoneNumber) async {
    await CallUtils.handleCallInitiation(
        phoneNumber: phoneNumber,
        context: context,
        callSourceLabel: "CUSTOMER_DETAILS",
    );
  }

  void _openChat(BuildContext context, int? jobId, String? customerId, String? expertId) {
    ClevertapSetup.logEvent(TrackingEvents.chatP2pclicked, {
      'job_id': jobId,
      'customer_id': customerId,
      'expert_id': expertId,
      'source': 'job',
    });
    Navigator.of(context).pushNamed(
      ChatScreen.routeName,
      arguments: {'source': 'button'},
    );
  }

  /// Show bottom sheet when disabled chat button is tapped
  void _showChatUnavailableBottomSheet(
    BuildContext context,
    LanguageProvider languageProvider,
    String? customerPhoneNumber,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.getMessage(
                  'chat_not_available_for_job',
                  'Chat is not available for this job.',
                ),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: customerPhoneNumber != null
                      ? () {
                          Navigator.of(context).pop();
                          _launchDialer(customerPhoneNumber);
                        }
                      : null,
                  icon: const Icon(Icons.call_rounded),
                  label: Text(
                    languageProvider.getMessage(
                        'call_customer', 'Call Customer'),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<RunnerRtDataProvider, _CustomerDetailsData>(
      selector: (_, provider) {
        final widgetData = provider.widgetInfo?.data;
        final chatInfoJson = widgetData?['chat_info'];
        ChatInfo? chatInfo;
        if (chatInfoJson != null) {
          try {
            chatInfo = ChatInfo.fromJson(chatInfoJson as Map<String, dynamic>);
          } catch (_) {}
        }
        final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
        return (
          customerName: widgetData?['customer_name'] as String?,
          customerPhNo: widgetData?['customer_ph_no'] as String?,
          customerId: widgetData?['customer_id']?.toString(),
          expertId: userProfileProvider.user?.id?.toString(),
          jobId: widgetData?['job_id'] as int?,
          hasChatInfo: chatInfo != null,
          unreadCount: chatInfo?.unreadCount ?? 0,
        );
      },
      builder: (context, data, _) {
        // If chat_info is available, mark that chat has been seen
        if (data.hasChatInfo) {
          _markChatAsSeen();
        }

        // Determine chat button state:
        // 1. chatInfo available → show enabled button
        // 2. chatInfo not available but seen before → show disabled button
        // 3. chatInfo not available and never seen → don't show button
        final bool showEnabledChatButton = data.hasChatInfo;
        final bool showDisabledChatButton =
            !data.hasChatInfo && _hasChatBeenSeenBefore;
        final bool showChatButton =
            showEnabledChatButton || showDisabledChatButton;
        final bool canCallCustomer = data.customerPhNo != null;

        return Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.person,
                size: 30.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  data.customerName ?? "Snabbit Customer",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              SizedBox(width: 8.w),
              // Chat Button - Three states:
              // 1. Enabled: chat_info is available
              // 2. Disabled: chat_info not available but was seen before
              // 3. Hidden: chat_info never available
              if (showEnabledChatButton)
                OutlinedButton(
                  onPressed: () {
                    final widgetData = Provider.of<RunnerRtDataProvider>(context, listen: false).widgetInfo?.data;
                    final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
                    final customerId = widgetData?['customer_id']?.toString();
                    final expertId = userProfileProvider.user?.id?.toString();

                    _openChat(context, data.jobId, customerId, expertId);
                    widget.onChatTap?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.n90,
                    side: const BorderSide(color: AppColors.n40),
                    padding: EdgeInsets.all(13.r),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 20.sp,
                          ),
                        ],
                      ),
                      if (data.unreadCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 8.r,
                            height: 8.r,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else if (showDisabledChatButton)
                OutlinedButton(
                  onPressed: () => _showChatUnavailableBottomSheet(
                    context,
                    languageProvider,
                    data.customerPhNo,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.n40,
                    side: const BorderSide(color: AppColors.n30),
                    padding: EdgeInsets.all(13.r),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 20.sp,
                        color: AppColors.n40,
                      ),
                      // Diagonal strike-through line
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DiagonalStrikePainter(color: AppColors.n40),
                        ),
                      ),
                    ],
                  ),
                ),
              if (showChatButton) SizedBox(width: 8.w),
              // Call Button
              SweepingShine(
                borderRadius: BorderRadius.circular(12.r),
                // Only sweep when the button is actionable.
                enabled: canCallCustomer,
                child: Container(
                  decoration: BoxDecoration(
                    color: canCallCustomer ? AppColors.n90 : AppColors.n40,
                  ),
                  child: OutlinedButton(
                    onPressed: canCallCustomer
                        ? () async {
                            ClevertapSetup.logEvent(
                                TrackingEvents.chatP2pCallClicked, {
                              'customer_id': data.customerId,
                              'job_id': data.jobId,
                              'expert_id': data.expertId,
                            });
                            widget.onCallTap?.call();
                            await CallUtils.handleCallInitiation(
                              phoneNumber: data.customerPhNo!,
                              context: context,
                              callSourceLabel: "CUSTOMER_DETAILS_CALL_BUTTON",
                              onSuccess: () {
                                ClevertapSetup.logEvent(
                                    TrackingEvents
                                        .chatP2pCallInitiatedSuccessfully,
                                    {
                                      'customer_id': data.customerId,
                                      'job_id': data.jobId,
                                      'expert_id': data.expertId,
                                    });
                              },
                              onFailure: ({e, st}) {
                                showSnackbar(
                                  context,
                                  languageProvider.getMessage(
                                      'unable_to_call_customer',
                                      'Unable to Call Customer'),
                                );
                              },
                            );
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      // White foreground so the icon and press ripple show on navy.
                      foregroundColor: AppColors.n0,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.all(13.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.call_rounded,
                          size: 20.sp,
                          // White on the navy fill; muted on the grey disabled fill.
                          color: canCallCustomer ? AppColors.n0 : AppColors.n70,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

/// Custom painter to draw a diagonal strike-through line
class _DiagonalStrikePainter extends CustomPainter {
  final Color color;

  _DiagonalStrikePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw diagonal line from top-right to bottom-left
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

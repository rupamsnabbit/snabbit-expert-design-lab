import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/payout/payout_info.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Green / yellow / expired — derived from how far the check-in deadline is from now.
enum _CheckInUrgency { green, yellow, expired }

/// Compact payout bar showing total earning with check-in bonus breakdown.
///
/// Used on Mark Arrival and Check-In screens (job_accepted.dart).
/// Renders nothing if [payoutInfo] is null.
class JobPayoutSummaryBar extends StatefulWidget {
  final PayoutInfo? payoutInfo;

  const JobPayoutSummaryBar({
    super.key,
    required this.payoutInfo,
  });

  @override
  State<JobPayoutSummaryBar> createState() => _JobPayoutSummaryBarState();
}

class _JobPayoutSummaryBarState extends State<JobPayoutSummaryBar> {
  Timer? _ticker;

  DateTime? get _checkInDeadline => widget.payoutInfo?.checkInTime;

  String? get _checkInTimeDisplay =>
      formatPayoutCheckInTimeDisplay(_checkInDeadline);

  _CheckInUrgency _urgency() {
    final target = _checkInDeadline;
    if (target == null) return _CheckInUrgency.green;
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return _CheckInUrgency.expired;
    if (diff.inMinutes < 15) return _CheckInUrgency.yellow;
    return _CheckInUrgency.green;
  }

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (_checkInDeadline != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant JobPayoutSummaryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldT = oldWidget.payoutInfo?.checkInTime;
    final newT = widget.payoutInfo?.checkInTime;
    if (oldT != newT) _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.payoutInfo;
    if (info == null) return const SizedBox.shrink();

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final total = info.totalEarning ?? 0;
        final checkInAmount = info.checkInAmount;
        final baseAmount =
            checkInAmount != null ? total - checkInAmount : total;
        final urgency = _urgency();
        final isExpired = urgency == _CheckInUrgency.expired;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider
                    .getMessage('you_will_earn', 'YOU WILL EARN')
                    .toUpperCase(),
                style: TextStyle(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Wrap(
                direction: Axis.horizontal,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4.w,
                runSpacing: 6.h,
                children: [
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        height: 28 / 20,
                      ),
                      children: [
                        TextSpan(
                          text: formatIndianCurrency(baseAmount),
                          style: const TextStyle(color: Color(0xFF374151)),
                        ),
                        if (checkInAmount != null && checkInAmount > 0)
                          TextSpan(
                            text: '  +  ${formatIndianCurrency(checkInAmount)}',
                            style: TextStyle(
                              color: isExpired
                                  ? const Color(0xFFE5E7EB)
                                  : const Color(0xFF374151),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (checkInAmount != null &&
                      checkInAmount > 0 &&
                      _checkInTimeDisplay != null)
                    _CheckInPill(
                      urgency: urgency,
                      label:
                          '${languageProvider.getMessage('check_in_by', 'Check In by')} $_checkInTimeDisplay',
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Rounded pill whose background/text color tracks timer urgency.
class _CheckInPill extends StatelessWidget {
  final _CheckInUrgency urgency;
  final String label;

  const _CheckInPill({required this.urgency, required this.label});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    switch (urgency) {
      case _CheckInUrgency.green:
        // Default / non-urgent state: blue (info), per Figma 7930:51314.
        bgColor = const Color(0xFFEFF6FF);
        borderColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1D4ED8);
        break;
      case _CheckInUrgency.yellow:
        bgColor = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        break;
      case _CheckInUrgency.expired:
        bgColor = const Color(0xFFF3F4F6);
        borderColor = bgColor;
        textColor = const Color(0xFFD1D5DB);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

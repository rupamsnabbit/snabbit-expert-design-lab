import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/referral.dart';

import 'package:snabbit_runner/referrals/widgets/add_referral.dart';
import 'package:snabbit_runner/referrals/widgets/referral_short_shift_info.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_widgets/gradient_border_container.dart';

class ReferralShiftCampaigns extends StatelessWidget {
  final String? source;

  const ReferralShiftCampaigns({super.key, this.source});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReferralDataProvider>(
      builder: (context, referralDataProvider, child) {
        final shiftReferralCampaigns =
            referralDataProvider.referralData?.shiftReferralCampaigns;
        if (shiftReferralCampaigns == null ||
            shiftReferralCampaigns.isEmpty == true) {
          return SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: shiftReferralCampaigns
                .map(
                  (campaign) => ReferralCampaignView(
                    isNewCampaign: campaign.isNewCampaign,
                    referralShiftType: campaign.referralShiftType,
                    shiftDurationMinHours: campaign.shiftDurationMinHours,
                    shiftDurationMaxHours: campaign.shiftDurationMaxHours,
                    referralAmount: campaign.referralAmount,
                    source: source,
                    daysOfValidity: campaign.daysOfValidity,
                    referralText: campaign.referralText,
                    onLearnMoreTap: campaign.showLearnMore
                        ? () {
                            ClevertapSetup.logEvent(
                                TrackingEvents
                                    .referralShiftCampaignLearnMoreTapped,
                                {
                                  'shift_type': campaign.referralShiftType?.key
                                });
                            if (campaign.referralShiftType ==
                                ReferralShiftType.shortShift) {
                              showReferralShortShiftInfoBottomSheet(
                                  context: context,
                                  minShiftHours: campaign.shiftDurationMinHours,
                                  maxShiftHours: campaign.shiftDurationMaxHours,
                                  referralAmount: campaign.referralAmount,
                                  maxEarnings: campaign.maxEarnings,
                                  onReferNowTap: () {
                                    if (campaign.referralShiftType == null) {
                                      return;
                                    }
                                    Navigator.pop(context);
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      constraints: BoxConstraints(
                                        maxHeight: 0.7.sh,
                                      ),
                                      builder: (_) {
                                        return AddReferral(
                                          referralShiftType:
                                              campaign.referralShiftType!,
                                          source: source,
                                          daysOfValidity:
                                              campaign.daysOfValidity,
                                          referralText: campaign.referralText,
                                        );
                                      },
                                    );
                                  });
                            }
                          }
                        : null,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

/// Stateless widget that renders a single referral campaign card.
///
/// The view is fully driven by nullable inputs – if a value is `null`, the
/// corresponding visual element is omitted from the UI. This allows the same
/// widget to be reused for multiple campaign configurations without leaking
/// assumptions about which parts are required.
class ReferralCampaignView extends StatelessWidget {
  /// Indicates whether the campaign should display the "NEW" ribbon.
  ///
  /// When this is `true`, a rotated ribbon is painted across the top-left
  /// edge of the card. When `false` or `null`, the ribbon is not shown.
  final bool? isNewCampaign;

  /// The shift type associated with this referral campaign.
  ///
  /// When non-null, this decides:
  /// - The main campaign title (part-time vs full-time referral).
  /// - The primary button label.
  /// - The `ReferralShiftType` passed to the `AddReferral` bottom sheet.
  ///
  /// When `null`, the title and primary button are hidden entirely.
  final ReferralShiftType? referralShiftType;

  /// Minimum shift duration in hours for the campaign, if available.
  ///
  /// Used together with [shiftDurationMaxHours] to render the
  /// "4–6 Hours shift" style pill on the right of the header row. If either
  /// bound is `null`, the pill is hidden.
  final int? shiftDurationMinHours;

  /// Maximum shift duration in hours for the campaign, if available.
  ///
  /// See [shiftDurationMinHours] for how this is used.
  final int? shiftDurationMaxHours;

  /// Formatted referral amount (for example, "₹6,000").
  ///
  /// When non-null, this is rendered using gradient text in the center of
  /// the card. When `null`, the amount row is omitted.
  final int? referralAmount;

  /// Optional tap handler for the "Learn More" pill.
  ///
  /// When non-null, a small pill button is shown near the bottom-right of
  /// the card. Tapping it invokes this callback. When `null`, the pill is
  /// hidden to avoid showing non-interactive UI.
  final VoidCallback? onLearnMoreTap;

  final String? source;

  final int? daysOfValidity;
  final String? referralText;

  /// Creates a new [ReferralCampaignView].
  ReferralCampaignView({
    super.key,
    this.isNewCampaign,
    this.referralShiftType,
    this.shiftDurationMinHours,
    this.shiftDurationMaxHours,
    this.referralAmount,
    this.onLearnMoreTap,
    this.source,
    this.daysOfValidity,
    this.referralText,
  });

  /// Returns the call-to-action label for the primary button.
  String? _buttonLabel(LanguageProvider languageProvider) {
    if (referralShiftType == null) return null;
    switch (referralShiftType!) {
      case ReferralShiftType.shortShift:
        return languageProvider.getMessage(
            'refer_part_time_now', 'Refer Part-time Now');
      case ReferralShiftType.fullTime:
        return languageProvider.getMessage(
            'refer_full_time_now', 'Refer Full-time Now');
    }
  }

  /// Builds the shift duration text when both bounds are available.
  String? _shiftDurationText(LanguageProvider languageProvider) {
    if (shiftDurationMinHours == null || shiftDurationMaxHours == null) {
      return null;
    }
    return languageProvider.getFormattedMessage(
        "shift_min_to_max_hours", "{{min_hours}}-{{max_hours}} Hours shift", {
      'min_hours': shiftDurationMinHours?.toString(),
      'max_hours': shiftDurationMaxHours?.toString()
    });
  }

  bool _eventLogged = false;

  void _logEvent() {
    if (_eventLogged) return;
    _eventLogged = true;
    ClevertapSetup.logEvent(TrackingEvents.referralHeaderBannerVisible, {
      'type': referralShiftType?.name,
      'source': source,
    });
  }

  @override
  Widget build(BuildContext context) {
    _logEvent();
    return Consumer<LanguageProvider>(builder: (context, languageProvider, _) {
      final String? title = referralShiftType?.displayText(languageProvider);
      final String? buttonLabel = _buttonLabel(languageProvider);
      final String? shiftDurationText = _shiftDurationText(languageProvider);

      return GradientBorderContainer(
        content: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(0, 51, 21, 0.3),
                Color.fromRGBO(0, 91, 44, 0.3),
              ],
            ),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null || referralAmount != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 16.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (title != null)
                                Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.14,
                                        color: AppColors.g0,
                                      ),
                                ),
                              if (title != null && shiftDurationText != null)
                                SizedBox(width: 8.w),
                              if (shiftDurationText != null)
                                Flexible(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    child: FittedBox(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 12.r,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            shiftDurationText,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                  letterSpacing: -0.24,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (title != null && referralAmount != null)
                            SizedBox(height: 4.h),
                          if (referralAmount != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Stack(
                                  children: [
                                    //shadow
                                    Text(
                                      formatIndianCurrency(referralAmount),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayLarge
                                          ?.copyWith(
                                        fontSize: 32.sp,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.n0,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0.5.w, 3.h),
                                            blurRadius: 0,
                                            color: const Color(0xFF6D2300),
                                          ),
                                        ],
                                      ),
                                    ),
                                    //border
                                    Text(
                                      formatIndianCurrency(referralAmount),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayLarge
                                          ?.copyWith(
                                            fontSize: 32.sp,
                                            fontWeight: FontWeight.w800,
                                            foreground: Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = 2
                                              ..color = Color(0xffFFB917),
                                          ),
                                    ),
                                    //gradient fill
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFFFFFAE8),
                                          Color(0xFFFFEF37),
                                          Color(0xFFFFB917),
                                        ],
                                        stops: [0.0625, 0.375, 0.8173],
                                      ).createShader(Offset.zero & bounds.size),
                                      blendMode: BlendMode.srcIn,
                                      child: Text(
                                        formatIndianCurrency(referralAmount),
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(
                                              fontSize: 32.sp,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.n0,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (onLearnMoreTap != null)
                                  Flexible(
                                    child: FittedBox(
                                      child: GestureDetector(
                                        onTap: onLearnMoreTap,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 6.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color.fromRGBO(
                                                255, 245, 182, 0.1),
                                            borderRadius:
                                                BorderRadius.circular(50.r),
                                            border: Border.all(
                                              color: const Color.fromRGBO(
                                                  255, 245, 182, 0.1),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.help_outlined,
                                                size: 12.r,
                                                color: const Color(0xFFFFF5B6),
                                              ),
                                              SizedBox(width: 4.w),
                                              FittedBox(
                                                child: Text(
                                                  languageProvider.getMessage(
                                                      'learn_more',
                                                      'Learn More'),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontSize: 12.sp,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                            0xFFFFF5B6),
                                                      ),
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              Icon(
                                                Icons.chevron_right,
                                                size: 18.r,
                                                color: const Color(0xFFFFF5B6),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  if (buttonLabel != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
                      child: GestureDetector(
                        onTap: () {
                          ClevertapSetup.logEvent(
                              TrackingEvents.referNowCtaClicked, {
                            'type': referralShiftType?.key,
                            'source': source,
                          });
                          if (referralShiftType == null) return;
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            constraints: BoxConstraints(
                              maxHeight: 0.7.sh,
                            ),
                            builder: (_) {
                              return AddReferral(
                                referralShiftType: referralShiftType!,
                                source: source,
                                daysOfValidity: daysOfValidity,
                                referralText: referralText,
                              );
                            },
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFFEF37),
                                Color(0xFFFFB917),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF953400),
                                offset: Offset(0, 2.h),
                                blurRadius: 0,
                              ),
                            ],
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Center(
                            child: FittedBox(
                              child: Text(
                                buttonLabel,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF953400),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (isNewCampaign == true)
                Positioned(
                  top: 5.h,
                  left: -24.w,
                  child: Transform.rotate(
                    angle: -45 * (math.pi / 180),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFFEC21C),
                            Color(0xFFFFE49A),
                            Color(0xFFFEC62A),
                            Color(0xFFFEC939),
                            Color(0xFFFDE8AD),
                            Color(0xFFFFBB00),
                            Color(0xFFF7C435),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.n0.withValues(alpha: 0.4),
                            offset: Offset(0, -2.h),
                            blurRadius: 0,
                            spreadRadius: 0,
                          ),
                        ],
                        borderRadius: BorderRadius.circular(50.r),
                      ),
                      child: Text(
                        languageProvider.getMessage('NEW', 'NEW'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: const Color(0xFF953400),
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x0000873B).withValues(alpha: 0.01),
            Color(0x6300873B).withValues(alpha: 0.3873),
            Color(0xFF00873B),
          ],
          stops: [
            0.0, // 0%
            0.3873, // 38.73%
            1.0, // 100%
          ],
        ),
        contentPadding: EdgeInsets.all(1.r),
        radius: 20,
        color: Colors.transparent,
        margin: EdgeInsets.only(bottom: 12.h),
      );
    });
  }
}

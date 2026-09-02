import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/referral.dart';
import 'package:snabbit_runner/referrals/widgets/referral_status_widget.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class FriendCardList extends StatelessWidget {
  final List<RunnerReferral> referrals;

  const FriendCardList({
    super.key,
    required this.referrals,
  });

  @override
  Widget build(BuildContext context) {
    if (referrals.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 18.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              referrals.length,
              (i) {
                int bonus = referrals[i].bonus ?? 0;
                int milestoneBonus =
                    referrals[i].milestoneConfig?.milestoneBonus ?? 0;
                bool isMilestoneAchieved =
                    referrals[i].milestoneConfig?.isAchieved ?? false;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        minWidth: 65.w,
                        maxWidth: 65.w,
                        minHeight: 66.h,
                        maxHeight: 190.h,
                      ),
                      child: FriendCard(
                        referralStatus: referrals[i].statusData?.status ==
                                    ReferralStatus.completed ||
                                referrals[i].statusData?.status ==
                                    ReferralStatus.paid
                            ? ReferralStatusEnum.joined
                            : ReferralStatusEnum.referred,
                        amount: bonus,
                        milestoneBonus: milestoneBonus,
                        friendName: referrals[i].name ?? "",
                        onTap: null,
                        isAchieved: isMilestoneAchieved,
                        profileImageUrl: referrals[i].image ??
                            AssetConstants.avatarImagePlaceholder,
                      ),
                    ),
                    if (i != referrals.length - 1) SizedBox(width: 8.w),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class FriendCard extends StatelessWidget {
  final String? profileImageUrl;
  final int amount;
  final String friendName;
  final VoidCallback? onTap;
  final ReferralStatusEnum referralStatus;
  final bool isAchieved;
  final int milestoneBonus;
  final double minAmountContainerWidth;
  final double minMilestoneContainerWidth;

  const FriendCard({
    super.key,
    this.profileImageUrl = AssetConstants.avatarImagePlaceholder,
    required this.milestoneBonus,
    required this.amount,
    required this.friendName,
    this.onTap,
    this.referralStatus = ReferralStatusEnum.referred,
    this.isAchieved = false,
    this.minAmountContainerWidth = 32,
    this.minMilestoneContainerWidth = 24,
  });

  Widget _buildResponsiveContainer({
    required BuildContext context,
    required String text,
    required double minWidth,
    required double maxWidth,
    required BoxDecoration decoration,
    required TextStyle? textStyle,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: maxWidth,
      ),
      child: Container(
        height: 16.h,
        padding: EdgeInsets.symmetric(
          horizontal: 6.7.w,
          vertical: 4.h,
        ),
        decoration: decoration,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: textStyle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return GestureDetector(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 64.h,
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 50.h,
                          child: Stack(
                            children: [
                              // Avatar
                              SizedBox(
                                width: maxWidth,
                                height: 40.h,
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 40.r,
                                    height: 40.r,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isAchieved == true
                                            ? const Color(0xffFAB914)
                                            : Colors.transparent,
                                        width: 1.w,
                                      ),
                                    ),
                                    child: ReferralStatusWidget(
                                      status: referralStatus,
                                      child: RemoteImageHandler(
                                        imageUrl: profileImageUrl!,
                                        width: 40.r,
                                        height: 40.r,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Main amount container
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _buildResponsiveContainer(
                                    context: context,
                                    text: formatIndianCurrency(amount),
                                    minWidth: minAmountContainerWidth,
                                    maxWidth: maxWidth,
                                    decoration: BoxDecoration(
                                      color: isAchieved == true
                                          ? null
                                          : const Color(0xff4F2597),
                                      gradient: isAchieved == true
                                          ? const LinearGradient(
                                              colors: [
                                                  Color(0xffFAB00B),
                                                  Color(0xffFCD731)
                                                ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter)
                                          : null,
                                      borderRadius:
                                          BorderRadius.circular(120.r),
                                    ),
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: isAchieved == true
                                              ? Color(0xff1D2129)
                                              : AppColors.n0,
                                          fontSize: 8.sp,
                                          fontWeight: FontWeight.w800,
                                          height: 1.sp,
                                          letterSpacing: 0,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Milestone bonus container - overlapping
                        if (milestoneBonus > 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _buildResponsiveContainer(
                                context: context,
                                text:
                                    "+ ${formatIndianCurrency(milestoneBonus)}",
                                minWidth: minMilestoneContainerWidth.w,
                                maxWidth: maxWidth,
                                decoration: BoxDecoration(
                                  color: isAchieved == true
                                      ? Color(0xffFFF2DB)
                                      : Color(0xffF5E8FF),
                                  borderRadius: BorderRadius.circular(120.r),
                                ),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isAchieved == true
                                          ? Color(0xffC57C07)
                                          : Color(0xff4F2597),
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.w800,
                                      height: 1.sp,
                                      letterSpacing: 0,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: 3.h),

                  // Friend Name
                  Text(
                    friendName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xff4F2597),
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

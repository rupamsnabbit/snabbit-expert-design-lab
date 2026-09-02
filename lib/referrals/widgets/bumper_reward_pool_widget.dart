import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/referral.dart';
import 'package:snabbit_runner/referrals/widgets/referral_header.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/countdown_timer_widget.dart';
import 'package:snabbit_runner/widgets/golden_text_widget.dart';
import 'package:snabbit_runner/widgets/how_it_works_modal.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/underline_text_button.dart';

class BumperRewardPoolWidget extends StatefulWidget {
  final ContestModel? contestData;
  final bool isContestRunning;

  const BumperRewardPoolWidget({
    super.key,
    this.contestData,
    this.isContestRunning = false,
  });

  @override
  BumperRewardPoolWidgetState createState() => BumperRewardPoolWidgetState();
}

class BumperRewardPoolWidgetState extends State<BumperRewardPoolWidget> {
  @override
  Widget build(BuildContext context) {
    // Don't show widget if no contest data
    if (widget.contestData == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      child: Container(
        margin: EdgeInsets.only(top: 16.h),
        decoration: BoxDecoration(
          color: AppColors.n0,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: widget.isContestRunning
              ? Column(
                  children: [
                    // Header Section
                    _buildHeader(),
                    SizedBox(height: 20.h),

                    // Main Content Card
                    _buildMainCard(),
                    SizedBox(height: 20.h),

                    // Action Buttons
                    _buildActionButtons(),
                  ],
                )
              : Column(
                  children: [
                    // Header Section
                    _buildCompletedHeader(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    bool isImageAvailable = widget.contestData?.prizeImage?.url != null ||
        widget.contestData?.prizeImage?.url != "";

    return Column(
      children: [
        // Title with trophy decorations
        Stack(
          children: [
            Positioned(
              child: Transform.translate(
                offset: Offset(-0.675 * 92.w, 0),
                child: Opacity(
                  opacity: 0.5,
                  child: Image.asset(
                    AssetConstants.diwaliContest.rank1TrophyPng,
                    width: 92.w,
                    height: 87.h,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Transform.translate(
                offset: Offset(0.675 * 92.w, 0),
                child: Opacity(
                  opacity: 0.5,
                  child: Image.asset(
                    AssetConstants.diwaliContest.rank1TrophyPng,
                    width: 92.w,
                    height: 87.h,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                children: [
                  CustomTextNS(
                    widget.contestData?.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 20.sp,
                          letterSpacing: -0.26,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xff1D2129),
                        ),
                  ),
                  SizedBox(height: 10.h),
                  if (isImageAvailable) ...[
                    RemoteImageHandler(
                      imageUrl: widget.contestData?.prizeImage?.url ?? "",
                      fit: BoxFit.cover,
                      errorWidget: Container(),
                    ),
                  ] else ...[
                    GoldenTextWidget.fromCustomText(
                      textData: widget.contestData?.displayPrize ?? {},
                      fontSize: 36.sp,
                    ),
                  ],
                  SizedBox(height: 10.h),
                  CustomTextNS(
                    widget.contestData?.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 14.sp,
                          color: const Color(0xff4E5969),
                          letterSpacing: -0.26,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 20.h),

        ContestTimerWidget(
          endDateTime: widget.contestData?.endDate ?? DateTime.now(),
        ),
      ],
    );
  }

  Widget _buildCompletedHeader() {
    return Column(
      children: [
        // Title with trophy decorations
        Stack(
          children: [
            Positioned(
              child: Transform.translate(
                offset: Offset(-0.675 * 92.w, 0),
                child: Opacity(
                  opacity: 0.5,
                  child: Image.asset(
                    AssetConstants.diwaliContest.rank1TrophyPng,
                    width: 92.w,
                    height: 87.h,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Transform.translate(
                offset: Offset(0.675 * 92.w, 0),
                child: Opacity(
                  opacity: 0.5,
                  child: Image.asset(
                    AssetConstants.diwaliContest.rank1TrophyPng,
                    width: 92.w,
                    height: 87.h,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                children: [
                  CustomTextNS(
                    widget.contestData?.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 20.sp,
                          letterSpacing: -0.26,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xff1D2129),
                        ),
                  ),
                  SizedBox(height: 20.h),
                  ContestTimerWidget(
                    endDateTime: widget.contestData?.endDate ?? DateTime.now(),
                  ),
                  SizedBox(height: 20.h),
                  ViewLeaderboardButton(contestData: widget.contestData),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainCard() {
    // Get standing details from contest data
    final standingDetails = widget.contestData?.standingDetail ?? [];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.n40, width: 1.r),
      ),
      child: Column(
        children: [
          // Build info rows from standing details
          ...List.generate(standingDetails.length, (index) {
            final detail = standingDetails[index];

            return Column(
              children: [
                _buildInfoRow(
                  iconAssetLink: detail.icon ??
                      AssetConstants.diwaliContest.iconExpertRank,
                  label: detail.title ?? {},
                  value: detail.value ?? "#1",
                ),
                if (index < standingDetails.length - 1) _buildDivider(),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String iconAssetLink,
    required Map<String, dynamic> label,
    required String value,
  }) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          SizedBox(
            width: 18.w,
            height: 22.h,
            child: Center(
              child: RemoteImageHandler(
                imageUrl: iconAssetLink,
                fit: BoxFit.cover,
                errorWidget: Container(),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: CustomTextNS(
              label,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 16.sp,
                    letterSpacing: -0.26,
                    height: 22 / 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff1D2129),
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 16.sp,
                  letterSpacing: -0.26,
                  height: 22 / 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff1D2129),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1.h,
      color: AppColors.n40,
    );
  }

  Widget _buildActionButtons() {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: true);
    return Column(
      children: [
        // View Leaderboard Button
        ViewLeaderboardButton(contestData: widget.contestData),

        SizedBox(height: 12.h),

        // View Rules Link
        UnderlineTextButton(
          onPressed: () {
            // Show rules modal with contest rules
            if (widget.contestData?.rules != null) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                constraints: BoxConstraints(
                  maxHeight: 0.7.sh,
                ),
                builder: (_) => HowItWorksModal(
                  videoUrl: null,
                  thumbnailUrl: null,
                  howItWorksSteps: widget.contestData!.rules!,
                  title: languageProvider.getMessage(
                    'how_to_win',
                    'How to win',
                  ),
                ),
              );
            }
          },
          text: languageProvider.getMessage(
            'view_bumper_reward_rules',
            'View Bumper Reward Rules',
          ),
          textColor: const Color(0xFF7711D2),
        ),
      ],
    );
  }
}

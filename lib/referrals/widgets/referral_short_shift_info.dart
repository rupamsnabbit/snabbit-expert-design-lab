import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Presents the [ReferralShortShiftInfo] widget inside a modal bottom sheet.
///
/// The sheet is wrapped with [CommonBottomSheetSetup] to match the app-wide
/// bottom-sheet styling conventions. Use [onReferNowTap] to react to the
/// primary CTA tap, and [audioUrl] to optionally provide a narration audio
/// that is played when the speaker icon is tapped.
void showReferralShortShiftInfoBottomSheet({
  required BuildContext context,
  VoidCallback? onReferNowTap,
  int? minShiftHours,
  int? maxShiftHours,
  int? referralAmount,
  int? maxEarnings,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.n0,
    builder: (sheetContext) {
      return SafeArea(
        child: CommonBottomSheetSetup(
          horizontalPadding: 0,
          bgColor: AppColors.n0,
          showDragHandle: false,
          child: ReferralShortShiftInfo(
            onReferNowTap: onReferNowTap,
            minShiftHours: minShiftHours,
            maxShiftHours: maxShiftHours,
            referralAmount: referralAmount,
            maxEarnings: maxEarnings,
          ),
        ),
      );
    },
  ).then((_) async {
    if (GlobalState().audioPlayer.state != PlayerState.playing) {
      return;
    }

    await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.stop);
    await GlobalState().audioPlayer.stop();
  });
}

/// Stateless widget rendering the "Referral Short Shift" information UI.
///
/// The layout closely matches the provided Figma design:
/// - A soft yellow gradient header with the "Earn ₹6,000" headline.
/// - An optional speaker icon to play a short narration via [audioUrl].
/// - A "What is Part-time Job?" section with three informational tiles.
/// - A "Who Can You Refer?" section with three profile rows.
/// - A primary "Refer & Earn Now" CTA button at the bottom.
///
/// The widget does not depend on any providers or services for strings and
/// only uses assets from [RemoteConfigAssets] and colors/text styles from
/// the app theme.
///
///
class ReferralShortShiftInfo extends StatefulWidget {
  /// Optional callback invoked when the primary "Refer & Earn Now" CTA is tapped.
  final VoidCallback? onReferNowTap;

  /// Optional URL used for playing the narration audio on speaker icon tap.
  ///
  /// When null or empty, the speaker icon becomes a no-op while still
  /// remaining visible to keep the UI consistent with the design.
  final String? audioUrl;

  final int? minShiftHours;
  final int? maxShiftHours;
  final int? referralAmount;
  final int? maxEarnings;

  /// Creates a new [ReferralShortShiftInfo] widget.
  const ReferralShortShiftInfo({
    super.key,
    this.onReferNowTap,
    this.audioUrl,
    this.minShiftHours,
    this.maxShiftHours,
    this.referralAmount,
    this.maxEarnings,
  });

  @override
  State<ReferralShortShiftInfo> createState() => _ReferralShortShiftInfoState();
}

class _ReferralShortShiftInfoState extends State<ReferralShortShiftInfo> {
  late LanguageProvider languageProvider;
  bool init = true;

  @override
  void initState() {
    super.initState();
    ClevertapSetup.logEvent(TrackingEvents.referralShortShiftInfoViewed, {
      'time_range': '${widget.minShiftHours} to ${widget.maxShiftHours}',
      'referral_amount': widget.referralAmount,
      'max_earnings': widget.maxEarnings,
    });
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Container(
        width: 1.sw,
        color: AppColors.n0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              languageProvider: languageProvider,
              referralAmount: widget.referralAmount,
            ),
            SizedBox(height: 24.h),
            _WhatIsPartTimeSection(
              languageProvider: languageProvider,
              maxEarnings: widget.maxEarnings,
              minShiftHours: widget.minShiftHours,
              maxShiftHours: widget.maxShiftHours,
            ),
            SizedBox(height: 24.h),
            _WhoCanYouReferSection(
              languageProvider: languageProvider,
            ),
            SizedBox(height: 32.h),
            _BottomCta(
              languageProvider: languageProvider,
              onReferNowTap: widget.onReferNowTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient headline text widget used for the "Earn ₹6,000" title.
///
/// This widget applies a vertical yellow-to-orange gradient to the text
/// to closely match the Figma design while still falling back to the
/// base style color when shaders are not available.
class _GradientHeadline extends StatelessWidget {
  /// Text content for the headline.
  final String text;

  /// Base text style used before applying the gradient shader.
  final TextStyle? baseStyle;

  /// Creates a new [_GradientHeadline] widget.
  const _GradientHeadline({
    required this.text,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle effectiveStyle =
        (baseStyle ?? Theme.of(context).textTheme.displayLarge) ??
            const TextStyle();

    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: effectiveStyle.copyWith(
            shadows: const [
              Shadow(
                offset: Offset(2, 3),
                blurRadius: 0,
                color: Color(0xFF6D2300),
              ),
            ],
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: effectiveStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Color(0xffFFB917),
          ),
        ),
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFAE8),
                Color(0xFFFFEF37),
                Color(0xFFFFB917),
              ],
              stops: [0.0, 0.4, 0.82],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(text, textAlign: TextAlign.center, style: effectiveStyle),
        ),
      ],
    );
  }
}

/// Tile widget used in the "What is Part-time Job?" section.
///
/// Displays a circular icon background with a remote image and a short
/// description below it.
class _PartTimeInfoTile extends StatelessWidget {
  /// Background color for the circular icon container.
  final Color backgroundColor;

  /// Remote image URL to be rendered inside the circular container.
  final String imageUrl;

  /// Single-line description text displayed under the icon.
  final String title;

  /// Creates a new [_PartTimeInfoTile] instance.
  const _PartTimeInfoTile({
    required this.backgroundColor,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60.r,
          height: 60.r,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(80.r),
          ),
          child: Center(
            child: RemoteImageHandler(
              imageUrl: imageUrl,
              height: 50.r,
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Flexible(
          child: SizedBox(
            width: 88.w,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.n90,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Row widget representing a single "Who Can You Refer?" profile entry.
///
/// Each row shows an avatar image on the left and a title/subtitle text
/// block on the right.
class _WhoToReferRow extends StatelessWidget {
  /// Remote image URL for the profile avatar.
  final String imageUrl;

  /// Primary title displayed on the first line.
  final String title;

  /// Secondary subtitle displayed on the second line.
  final String subtitle;

  /// Creates a new [_WhoToReferRow] instance.
  const _WhoToReferRow({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60.r,
          height: 60.r,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(60.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: RemoteImageHandler(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.n90,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                    letterSpacing: -0.0024,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int? referralAmount;
  final LanguageProvider languageProvider;

  const _Header({
    super.key,
    this.referralAmount,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 1.sw,
      height: 138.h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF3B6),
            Color(0xFFFBFFE2),
            AppColors.n0,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 40.h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox.shrink(),
                  const Spacer(),
                  SizedBox(
                    height: 40.h,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => _handleAudioTap(context),
                        child: Container(
                          width: 36.r,
                          height: 36.r,
                          decoration: BoxDecoration(
                            color: AppColors.n0,
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: AppColors.n50,
                              width: 0.9.w,
                            ),
                          ),
                          child: Center(
                            child: RemoteImageHandler(
                              imageUrl: RemoteConfigAssets
                                  .sundayAttendanceNudgePlayAudio,
                              height: 18.r,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            _GradientHeadline(
              text: languageProvider.getFormattedMessage("earn_x", 'Earn {{x}}',
                  {'x': formatIndianCurrency(referralAmount)}),
              baseStyle: textTheme.displayLarge?.copyWith(
                fontSize: 32.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6D2300),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              languageProvider.getMessage('for_every_part_time_referral',
                  'For Every Part-Time Referral'),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6D2300),
                letterSpacing: -0.0024,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles the speaker icon tap by playing [audioUrl] using the shared
  /// [GlobalState] audio player instance.
  Future<void> _handleAudioTap(BuildContext context) async {
    try {
      final userProfileProvider = context.read<UserProfileProvider>();
      final languageCode = (userProfileProvider.user?.languagePreference ??
              AppStrings.defaultLanguage)
          .toLowerCase();
      ClevertapSetup.logEvent(TrackingEvents.referralShortShiftInfoAudioRequested, {
        'language': languageCode
      });
      final url = RemoteConfigAssets.referralShortShiftBenefitsAudio
          .replaceAll("{{language_code}}", languageCode);
      if (url.isEmpty) {
        return;
      }

      if (GlobalState().audioPlayer.state == PlayerState.playing) {
        return;
      }

      await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.release);
      await GlobalState().audioPlayer.play(UrlSource(url), volume: 1.0);
    } catch (_) {
      // Audio failures are non-blocking for this informational widget.
    }
  }
}

/// Builds the primary "Refer & Earn Now" CTA button at the bottom.
class _BottomCta extends StatelessWidget {
  final VoidCallback? onReferNowTap;
  final LanguageProvider languageProvider;

  const _BottomCta(
      {super.key, this.onReferNowTap, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GestureDetector(
        onTap: onReferNowTap,
        child: Container(
          width: 1.sw,
          height: 44.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFEF37),
                Color(0xFFFFB917),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF953400),
                offset: Offset(0, 2),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            languageProvider.getMessage(
                'refer_and_earn_now', 'Refer & Earn Now'),
            textAlign: TextAlign.center,
            style: textTheme.labelLarge?.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF953400),
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds the "What is Part-time Job?" title and the three informational tiles
/// for shift duration, timing, and income.
class _WhatIsPartTimeSection extends StatelessWidget {
  final int? minShiftHours;
  final int? maxShiftHours;
  final int? maxEarnings;
  final LanguageProvider languageProvider;

  const _WhatIsPartTimeSection({
    super.key,
    this.minShiftHours,
    this.maxShiftHours,
    this.maxEarnings,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            languageProvider.getMessage(
                'what_is_part_time_job', 'What is Part-time Job?'),
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.n90,
              letterSpacing: -0.0024,
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            width: 1.sw,
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _PartTimeInfoTile(
                      backgroundColor: const Color(0xFFEFF7FF),
                      imageUrl: RemoteConfigAssets.referralShortShiftDurations,
                      title: languageProvider.getFormattedMessage(
                          "shift_min_to_max_hours",
                          "{{min_hours}}-{{max_hours}} Hours shift", {
                        "min_hours": minShiftHours,
                        "max_hours": maxShiftHours,
                      }),
                    ),
                  ),
                  VerticalDivider(
                    width: 1.r,
                    thickness: 1.r,
                    color: AppColors.n20,
                  ),
                  Expanded(
                    child: _PartTimeInfoTile(
                      backgroundColor: const Color(0xFFFFF8EC),
                      imageUrl: RemoteConfigAssets.referralShortShiftTimings,
                      title: languageProvider.getMessage(
                          'morning_or_evening_hours',
                          'Morning or evening hours'),
                    ),
                  ),
                  VerticalDivider(
                    width: 1.r,
                    thickness: 1.r,
                    color: AppColors.n20,
                  ),
                  Expanded(
                    child: _PartTimeInfoTile(
                      backgroundColor: const Color(0xFFEFFFF5),
                      imageUrl: RemoteConfigAssets.referralShortShiftIncome,
                      title: languageProvider.getFormattedMessage(
                          'earn_up_to_x', 'Earn up to {{x}}', {
                        'x': formatIndianCurrency(maxEarnings ?? 20000),
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds the "Who Can You Refer?" section with three profile rows.
class _WhoCanYouReferSection extends StatelessWidget {
  final LanguageProvider languageProvider;

  const _WhoCanYouReferSection({super.key, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            languageProvider.getMessage(
                'who_can_you_refer', 'Who Can You Refer?'),
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.n90,
              letterSpacing: -0.0024,
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            width: 1.sw,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: AppColors.n0,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: const Color(0xFFD9D9D9),
                width: 1.w,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WhoToReferRow(
                  imageUrl: RemoteConfigAssets.referralShortShiftWhoToRefer1,
                  title: languageProvider.getMessage(
                      'friends_with_free_time', 'Friends with free time'),
                  subtitle: languageProvider.getMessage(
                      'before_10am_or_after_5pm', 'Before 10am or after 5pm'),
                ),
                Divider(
                  height: 24.h,
                  thickness: 1.5.w,
                  color: AppColors.n20,
                ),
                _WhoToReferRow(
                  imageUrl: RemoteConfigAssets.referralShortShiftWhoToRefer2,
                  title:
                      languageProvider.getMessage('homemakers', 'Homemakers'),
                  subtitle: languageProvider.getMessage(
                      'who_wants_to_work_and_earn',
                      'Who wants to work and earn'),
                ),
                Divider(
                  height: 24.h,
                  thickness: 1.5.w,
                  color: AppColors.n20,
                ),
                _WhoToReferRow(
                  imageUrl: RemoteConfigAssets.referralShortShiftWhoToRefer3,
                  title: languageProvider.getMessage(
                      'women_with_children', 'Women with Children'),
                  subtitle: languageProvider.getMessage(
                      'who_are_looking_for_flexible_work',
                      'who are looking for flexible work'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

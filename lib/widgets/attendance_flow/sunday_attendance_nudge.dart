import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../utils/app_strings.dart';
import '../common_widgets/custom_text_highlighter.dart';

/// Shows the SundayAttendanceNudge bottom sheet wrapped in the common
/// bottom-sheet setup.
///
/// The sheet matches the provided Figma design and exposes callbacks
/// for the primary CTA, secondary action, and optional speaker icon.
void showSundayAttendanceNudgeBottomSheet({
  required BuildContext context,
  VoidCallback? onWorkTomorrowTap,
  VoidCallback? onKeepSundayAsLeaveTap,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.n0,
    builder: (context) {
      return SafeArea(
        child: CommonBottomSheetSetup(
          horizontalPadding: 0,
          bgColor: AppColors.n0,
          showDragHandle: false,
          child: SundayAttendanceNudge(
            onWorkTomorrowTap: onWorkTomorrowTap,
            onKeepSundayAsLeaveTap: onKeepSundayAsLeaveTap,
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

/// Widget rendering the Sunday attendance nudge bottom sheet content.
///
/// This widget is designed to be displayed only via
/// [showSundayAttendanceNudgeBottomSheet] so that provider wiring and
/// modal presentation stay consistent.
class SundayAttendanceNudge extends StatefulWidget {
  /// Optional callback for the primary CTA:
  /// "Work Tomorrow & Earn More".
  final VoidCallback? onWorkTomorrowTap;

  /// Optional callback for the secondary action:
  /// "Keep Sunday as Leave".
  final VoidCallback? onKeepSundayAsLeaveTap;

  const SundayAttendanceNudge({
    super.key,
    this.onWorkTomorrowTap,
    this.onKeepSundayAsLeaveTap,
  });

  @override
  State<SundayAttendanceNudge> createState() => _SundayAttendanceNudgeState();
}

class _SundayAttendanceNudgeState extends State<SundayAttendanceNudge> {
  /// Ensures dependency initialisation runs only once.
  bool init = true;

  /// Language provider for future localisation of strings.
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      ClevertapSetup.logEvent(
        TrackingEvents.sundayAttendanceNudgeViewed,
        {},
      );
    }
  }

  /// Returns the title to be displayed in the header section.
  String get _title {
    return languageProvider.getMessage(
      'sunday_attendance_nudge_headline',
      'Kal Absent Mat Rahiye',
    );
  }

  /// Returns the subtitle displayed under the title.
  String get _subTitle {
    return languageProvider.getMessage(
      'sunday_attendance_nudge_subheading',
      'Sunday = Extra Kamayi Ka Din!',
    );
  }

  int get _mingAmount {
    return anyValueToInt(
            runnerRtDataProvider.widgetInfo?.data?['ming_amount']) ??
        0;
  }

  /// Returns the MinG row text.
  String get _minGText {
    return languageProvider.getFormattedMessage(
        'sunday_attendance_nudge_min_g_line',
        'Kal aapki MinG {{Rs {{ming_amount}} hai}}', {
      'ming_amount': _mingAmount,
    });
  }

  /// Returns the weekday uplift row text.
  String get _weekdayUpliftText {
    return languageProvider.getMessage(
      'sunday_attendance_nudge_higher_earnings_line',
      'Weekday se {{30% zyada kamayi}}',
    );
  }

  int get _bonusAmount {
    return anyValueToInt(
            runnerRtDataProvider.widgetInfo?.data?['performance_bonus']) ??
        0;
  }

  /// Returns the bonus row text.
  String get _bonusText {
    return languageProvider.getFormattedMessage(
        'sunday_attendance_nudge_bonus_eligibility_line',
        '{{Rs {{bonus_amount}}}} ka bonus eligible', {
      'bonus_amount': _bonusAmount,
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTopHeader(context),
          SizedBox(height: 36.h),
          _buildTitleSection(context, textTheme),
          SizedBox(height: 36.h),
          _buildInfoCard(context, textTheme),
          SizedBox(height: 40.h),
          _BottomActions(
            onWorkTomorrowTap: widget.onWorkTomorrowTap,
            onKeepSundayAsLeaveTap: widget.onKeepSundayAsLeaveTap,
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  /// Builds the decorative top gradient header and illustration.
  Widget _buildTopHeader(BuildContext context) {
    return SizedBox(
      width: 1.sw,
      child: Stack(
        children: [
          // Central illustration.
          Align(
            alignment: Alignment.center,
            child: RemoteImageHandler(
              imageUrl: RemoteConfigAssets.sundayAttendanceNudgeTopBanner,
              // height: 140.h,
              // width: 140.w,
              fit: BoxFit.contain,
            ),
          ),
          // Speaker icon button.
          Positioned(
            right: 20.w,
            top: 20.h,
            child: InkWell(
              onTap: () async {
                final languageCode =
                    (userProfileProvider.user?.languagePreference ??
                            AppStrings.defaultLanguage)
                        .toLowerCase();

                try {
                  ClevertapSetup.logEvent(
                    TrackingEvents.sundayAttendanceNudgeAudioPlayClicked,
                    {
                      "language": languageCode,
                    },
                  );
                  final url = RemoteConfigAssets
                      .sundayAttendanceNudgeBaseAudioPath
                      .replaceAll("{{language_code}}", languageCode);
                  if (url.isEmpty) return;

                  // Don’t restart if already playing the same thing (optional).
                  if (GlobalState().audioPlayer.state == PlayerState.playing) {
                    return;
                  }

                  await GlobalState()
                      .audioPlayer
                      .setReleaseMode(ReleaseMode.release);
                  await GlobalState()
                      .audioPlayer
                      .play(UrlSource(url), volume: 1);
                  ClevertapSetup.logEvent(
                    TrackingEvents.sundayAttendanceNudgeAudioPlayed,
                    {
                      "language": languageCode,
                    },
                  );
                } catch (e) {
                  MonitoringServiceHelper.logError("FAILED_TO_PLAY_AUDIO", {
                    "error": e.toString(),
                    "language": languageCode,
                  });
                }
              },
              child: Container(
                width: 52.r,
                height: 52.r,
                decoration: BoxDecoration(
                  color: AppColors.n0,
                  borderRadius: BorderRadius.circular(26.67.r),
                  border: Border.all(
                    color: AppColors.n50,
                    width: 1.33.w,
                  ),
                ),
                child: Center(
                  child: RemoteImageHandler(
                    imageUrl: RemoteConfigAssets.sundayAttendanceNudgePlayAudio,
                    height: 18.r,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the title and subtitle block beneath the header.
  Widget _buildTitleSection(BuildContext context, TextTheme textTheme) {
    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _title,
            textAlign: TextAlign.center,
            style: textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.26,
              color: AppColors.n90,
              height: (24 / 24).sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _subTitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 18.sp,
              color: AppColors.y60,
              height: (18 / 18).sp,
              letterSpacing: -0.26,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the main informational card listing MinG, weekday uplift,
  /// and bonus rows with their corresponding icons.
  Widget _buildInfoCard(BuildContext context, TextTheme textTheme) {
    final Color borderColor = Color(0xFFF2F3F7);

    return Container(
      width: 337.w,
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: borderColor,
          width: 1.2.r,
        ),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_mingAmount > 0)
                DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFF9FAFB),
                          Color(0xFFE5FEF5),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                        topRight: Radius.circular(20.r),
                      ),
                      border: Border(
                          bottom: BorderSide(
                        color: borderColor,
                        width: 1.r,
                      ))),
                  child: _InfoRow(
                    imageUrl: RemoteConfigAssets.sundayAttendanceMing,
                    text: _minGText,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.autoOtTextPrimary,
                      letterSpacing: -0.003,
                    ),
                    highlightStyle: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.g40,
                      letterSpacing: -0.003,
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                  color: borderColor,
                  width: 1.r,
                ))),
                child: _InfoRow(
                  imageUrl: RemoteConfigAssets.sundayAttendanceExtraIncome,
                  text: _weekdayUpliftText,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.autoOtTextPrimary,
                    letterSpacing: -0.003,
                  ),
                  highlightStyle: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.autoOtTextPrimary,
                    letterSpacing: -0.003,
                  ),
                ),
              ),
              if (_bonusAmount > 0)
                _InfoRow(
                  imageUrl: RemoteConfigAssets.sundayAttendanceNudgeBonus,
                  text: _bonusText,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.autoOtTextPrimary,
                    letterSpacing: -0.003,
                  ),
                  highlightStyle: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.autoOtTextPrimary,
                    letterSpacing: -0.003,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.imageUrl,
    required this.text,
    this.style,
    this.highlightStyle,
  });

  final String imageUrl;
  final String text;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40.h,
      margin: EdgeInsets.symmetric(
        vertical: 10.h,
        horizontal: 16.w,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RemoteImageHandler(
            imageUrl: imageUrl,
            width: 40.w,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 12.w),
          Expanded(
              child: CustomTextHighlighter(
            text: text,
            textStyle: style,
            customHighlighter: (String text) {
              return Text(text, style: highlightStyle);
            },
          )),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  /// Optional callback for the primary CTA:
  /// "Work Tomorrow & Earn More".
  final VoidCallback? onWorkTomorrowTap;

  /// Optional callback for the secondary action:
  /// "Keep Sunday as Leave".
  final VoidCallback? onKeepSundayAsLeaveTap;

  const _BottomActions({
    super.key,
    this.onWorkTomorrowTap,
    this.onKeepSundayAsLeaveTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Consumer<LanguageProvider>(builder: (context, languageProvider, _) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48.h,
              child: ElevatedButton(
                onPressed: () {
                  ClevertapSetup.logEvent(
                    TrackingEvents.sundayAttendanceNudgeWorkTomorrow,
                    {},
                  );
                  onWorkTomorrowTap?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.g40,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  languageProvider.getMessage(
                    'sunday_attendance_nudge_primary_cta',
                    'Work Tomorrow & Earn More',
                  ),
                  textAlign: TextAlign.center,
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.n0,
                    letterSpacing: -0.24,
                    height: (20 / 15).sp,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              height: 36.h,
              child: TextButton(
                onPressed: () {
                  ClevertapSetup.logEvent(
                    TrackingEvents.sundayAttendanceNudgeWorkSundayLeave,
                    {},
                  );
                  onKeepSundayAsLeaveTap?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.n80,
                ),
                child: Text(
                  languageProvider.getMessage(
                    'sunday_attendance_nudge_secondary_cta',
                    'Keep Sunday as Leave',
                  ),
                  textAlign: TextAlign.center,
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.n80,
                    letterSpacing: -0.24,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

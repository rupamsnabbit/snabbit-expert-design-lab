import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/job_http.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';
import 'package:snabbit_runner/widgets/gamification/sheet_warning_attendance.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../constants/assets_constants.dart';
import '../banner_with_media.dart';
import '../../utils/colors.dart';
import 'earning_loss_bottom_sheet.dart';
import 'sunday_attendance_nudge.dart';

class AttendanceConfirmed extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const AttendanceConfirmed({
    super.key,
    this.widgetData,
  });

  @override
  State<AttendanceConfirmed> createState() => _AttendanceConfirmedState();
}

class _AttendanceConfirmedState extends State<AttendanceConfirmed> {
  bool init = true;

  bool loading = true;

  late LanguageProvider languageProvider;

  late RunnerRtDataProvider runnerRtDataProvider;
  late UserProfileProvider userProfileProvider;

  Future<void> initProcess() async {}

  /// Core “mark absent” API + overlays after the user has finished confirm UI.
  Future<void> _commitChangeToAbsentFromConfirmed() async {
    runnerRtDataProvider.setWaitForFetchData(true);
    await ClevertapSetup.logEvent(
      TrackingEvents.attendanceChanged,
      {"runner_attendance_confirmed": "attendance change", "from": "confirmed"},
    );
    final Response? response = await JobHttp.changeAttendance(
      data: {
        "mark": false,
        "shift_date": widget.widgetData?["start_date_ist"],
      },
    );
    if (response != null && response.statusCode == 200) {
      await PostActionOverlayController.instance.showFromResponse(
        response.data,
        LifecycleActionType.falseAttendance,
      );
    } else {
      if (context.mounted) {
        showSnackbar(
          context,
          "${response?.data ?? "Something went wrong. Please try again!"}",
        );
      }
    }
    await runnerRtDataProvider.fetchDataNow();
  }

  Future<void> _onEarningLossChoseAbsent() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      await _commitChangeToAbsentFromConfirmed();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    init = false;
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: true);
    runnerRtDataProvider =
        Provider.of<RunnerRtDataProvider>(context, listen: true);

    initProcess().then((_) {
      loading = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.widgetData == null
        ? Container()
        : runnerRtDataProvider.waitForFetchData == true
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : Column(
                children: [
                  const LoginEarlyBonusBanner(),
                  Text(
                    "${widget.widgetData!["date"] ?? ""}",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(
                    height: 4.h,
                  ),
                  Text(
                    "${widget.widgetData!["shift_time"] ?? ""}",
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: const Divider(
                      color: AppColors.n30,
                    ),
                  ),
                  if (widget.widgetData?["show_rain_warning"] == true)
                    Container(
                      margin: EdgeInsets.only(bottom: 16.h),
                      height: 72.h,
                      child: BannerWithMedia(
                        message: widget.widgetData?["rain_warning_text"],
                        foregroundImage:
                            userProfileProvider.user?.alternateDeliveryMethod ==
                                    AlternateDeliveryMethod.yulu
                                ? AssetConstants.expertYuluRaincoat
                                : AssetConstants.expertUmbrella,
                        backgroundImage: AssetConstants.rainBannerBg,
                      ),
                    ),
                  Container(
                    width: 48.r,
                    height: 48.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.g40,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.n0,
                      size: 28.sp,
                    ),
                  ),
                  SizedBox(height: 28.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 50.w),
                    child: Text(
                      languageProvider.getMessage(
                          "tomorrows_attendance_marked_as",
                          "Tomorrow's attendance marked as"),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),

                  // widget.widgetData!["type"] == "TOMORROW" &&
                  widget.widgetData!["change_atn"] == true
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Column(
                            children: [
                              Text(
                                languageProvider.getMessage(
                                    "present", "Present"),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20.sp,
                                        color: AppColors.g50),
                              ),
                              SizedBox(height: 16.h),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.r50,
                                  side: const BorderSide(color: AppColors.n30),
                                ),
                                child: FittedBox(
                                  child: Text(
                                    languageProvider.getMessage(
                                      "change_attendance",
                                      "Change attendance",
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (modalContext) {
                                      return EarningLossBottomSheet(
                                        earningLossAmount: widget.widgetData![
                                                    'earning_loss_amount']
                                                ?.toString() ??
                                            '',
                                        onMarkAbsent: () {
                                          if (widget.widgetData?[
                                                  "is_next_working_day_sunday"] ==
                                              true) {
                                            Navigator.pop(modalContext);
                                            showSundayAttendanceNudgeBottomSheet(
                                              context: context,
                                              onKeepSundayAsLeaveTap: () async {
                                                Navigator.of(context).pop();
                                                await _onEarningLossChoseAbsent();
                                              },
                                              onWorkTomorrowTap: () {
                                                Navigator.of(context).pop();
                                              },
                                            );
                                          } else {
                                            Navigator.pop(modalContext);
                                            _onEarningLossChoseAbsent();
                                          }
                                        },
                                        onMarkPresent: () {
                                          Navigator.pop(modalContext);
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      : Container(),
                ],
              );
  }
}

/// CTA from Figma: Expert-App-2.0 / View Today's Earnings (emerald bar, white ₹ chip).
class ViewTodaysEarningsButton extends StatelessWidget {
  static const _bg = Color(0xFF059669);

  final String label;
  final VoidCallback onPressed;

  const ViewTodaysEarningsButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.r),
        child: SizedBox(
          width: double.infinity,
          height: 56.h,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24.r,
                height: 24.r,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.n0,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '₹',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _bg,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.n0,
                      fontWeight: FontWeight.w600,
                      fontSize: 16.sp,
                      height: 24 / 16,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChangeAbsentConfirmation extends StatefulWidget {
  final Function() onPositiveAction;
  final Function()? onNegativeAction;

  const ChangeAbsentConfirmation({
    super.key,
    required this.onPositiveAction,
    this.onNegativeAction,
  });

  @override
  State<ChangeAbsentConfirmation> createState() =>
      ChangeAbsentConfirmationState();
}

class ChangeAbsentConfirmationState extends State<ChangeAbsentConfirmation> {
  bool init = true;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetNudges = filterSheetWarnings(
      runnerRtDataProvider.sheetWarnings,
      AttendanceSheetLifecycle.provisionalMarkAbsent,
    );
    final ctaMap = ctaOverridesForSheet(sheetNudges);
    final primaryCta = ctaMap[AttendanceSheetCtaIds.markAbsent];
    final secondaryCta = ctaMap[AttendanceSheetCtaIds.goBack];

    return runnerRtDataProvider.waitForFetchData == true
        ? SizedBox(
            height: 0.2.sh,
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16.h),
              Image.asset(
                AssetConstants.absentSadRed,
                height: 117.r,
              ),
              SizedBox(height: 20.h),
              Text(
                languageProvider.getMessage(
                  "mark_absent",
                  "Mark absent?",
                ),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: () async {
                    widget.onPositiveAction();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.g40,
                  ),
                  child: attendanceSheetCtaButtonChild(
                    context,
                    cta: primaryCta,
                    languageProvider: languageProvider,
                    fallbackKey: 'yes',
                    fallbackEnglish: 'Yes',
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.onNegativeAction != null) {
                      widget.onNegativeAction!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.r40,
                  ),
                  child: attendanceSheetCtaButtonChild(
                    context,
                    cta: secondaryCta,
                    languageProvider: languageProvider,
                    fallbackKey: 'no',
                    fallbackEnglish: 'No',
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          );
  }
}

class AmountBanner extends StatelessWidget {
  final Widget title;
  final String? subtitle;
  final String image;
  final int? amount;
  final double? valueBoxSize;
  final double? prefixIconSize;
  final String? bottomPrefix;
  final Color? amountColor;

  const AmountBanner({
    super.key,
    required this.title,
    this.subtitle,
    required this.image,
    this.amount,
    this.valueBoxSize,
    this.prefixIconSize,
    this.bottomPrefix,
    this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    try {
      // Added try-catch just for safety.
      return Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return Stack(
            children: [
              if (image.startsWith("https"))
                RemoteImageHandler(imageUrl: image)
              else
                Image.asset(image),
              if (bottomPrefix != null)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 26.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff03445F),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(4.r),
                          bottomLeft: const Radius.circular(16),
                        ),
                      ),
                      child: PopUpText(text: bottomPrefix ?? ""),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: prefixIconSize ?? 80.w,
                      ),
                      Expanded(child: title),
                      SizedBox(
                        width: valueBoxSize ?? 100.w,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (amount != null)
                              Text(
                                "${amount! < 0 ? "-" : ""}₹${amount?.abs()}",
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium
                                    ?.copyWith(
                                      fontSize: 33.sp,
                                      color: amountColor ?? AppColors.n0,
                                    ),
                              ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.copyWith(
                                      fontSize: 14.sp,
                                      color: AppColors.n0,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      return const SizedBox();
    }
  }
}

/// A widget that displays text with a popping animation
class PopUpText extends StatefulWidget {
  final String text;

  const PopUpText({
    super.key,
    required this.text,
  });

  @override
  State<PopUpText> createState() => _PopUpTextState();
}

class _PopUpTextState extends State<PopUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Create animation controller with duration
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Scale animation: 1.0 -> 1.15 -> 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Opacity animation: 0.85 -> 1.0 -> 0.85
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.0),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.85),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Text(
              widget.text,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.n0,
                  ),
            ),
          ),
        );
      },
    );
  }
}

class LoginEarlyBonusBanner extends StatefulWidget {
  const LoginEarlyBonusBanner({super.key});

  @override
  State<LoginEarlyBonusBanner> createState() => _LoginEarlyBonusBannerState();
}

class _LoginEarlyBonusBannerState extends State<LoginEarlyBonusBanner> {
  bool _loadTracked = false;

  void _trackLoadIfNeeded(Map<String, dynamic>? data) {
    if (_loadTracked) return;
    if (data?['show_early_login_bonus'] != true) return;
    _loadTracked = true;
    final props = <String, dynamic>{
      'early_login_bonus_amount': data?['early_login_bonus_amount'],
      'login_by_time': data?['login_by_time'],
    };
    MixpanelSetup.logEvent(TrackingEvents.earlyLoginNudgeLoad, props);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Consumer<RunnerRtDataProvider>(
          builder: (context, runnerRtDataProvider, child) {
            // Fire screen-load once per widget lifetime, gated on the
            // visibility flag — the banner is rebuilt on provider
            // changes, so a flag avoids dupes.
            _trackLoadIfNeeded(runnerRtDataProvider.widgetInfo?.data);
            if (runnerRtDataProvider
                    .widgetInfo?.data?['show_early_login_bonus'] ==
                true) {
              return Padding(
                padding: EdgeInsets.only(bottom: 24.h),
                child: AmountBanner(
                  valueBoxSize: 12.w,
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getFormattedMessage(
                          'good_shift_login_by_x',
                          'Do GOOD SHIFT, Login by {{shift_time}}',
                          {
                            "shift_time": runnerRtDataProvider
                                .widgetInfo?.data?['login_by_time']
                                .toString()
                          },
                        ),
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.n90,
                                ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        languageProvider.getFormattedMessage(
                          'earn_x_login_bonus',
                          'Earn {{amount}}',
                          {
                            "amount": formatIndianCurrency(anyValueToInt(
                                runnerRtDataProvider.widgetInfo
                                    ?.data?['early_login_bonus_amount']))
                          },
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.n90,
                            ),
                      ),
                    ],
                  ),
                  image: runnerRtDataProvider
                          .widgetInfo?.data?['early_login_banner_url']
                          ?.toString()
                          .cdn ??
                      "home/early_login_bonus_bg.png".cdn,
                ),
              );
            } else {
              return const SizedBox();
            }
          },
        );
      },
    );
  }
}

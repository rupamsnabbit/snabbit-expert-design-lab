import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/selfie_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/gamification/cta_badge.dart';
import 'package:snabbit_runner/widgets/job_login/selfie_login.dart';

class AutoLoginBottomActionButton extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const AutoLoginBottomActionButton({
    super.key,
    required this.widgetData,
  });

  @override
  State<AutoLoginBottomActionButton> createState() =>
      _AutoLoginBottomActionButtonState();
}

class _AutoLoginBottomActionButtonState
    extends State<AutoLoginBottomActionButton>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  Color acceptButtonFg = AppColors.g50;
  Color acceptButtonBg = AppColors.g30;

  late bool? autoLoginEnabled;
  late int? autoLoginSeconds;
  late DateTime? autoLoginAcknowledgementTime;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    autoLoginEnabled = widget.widgetData?['auto_login_enabled'];
    autoLoginAcknowledgementTime = widget
                .widgetData?['auto_login_acknowledged_at'] !=
            null
        ? DateTime.tryParse(widget.widgetData!['auto_login_acknowledged_at'])
            ?.toLocal()
        : null;
    autoLoginSeconds = anyValueToInt(widget.widgetData?['auto_login_seconds']);

    // Only set up animation if auto login is enabled and has valid data
    if (autoLoginEnabled == true &&
        autoLoginAcknowledgementTime != null &&
        autoLoginSeconds != null) {
      // Calculate animation duration based on acknowledgment time and remaining seconds
      final expiryTime = autoLoginAcknowledgementTime!
          .add(Duration(seconds: autoLoginSeconds!));
      final remainingTime = expiryTime.difference(DateTime.now());

      // Use remaining time if positive, otherwise use total seconds as fallback
      final animationDuration = remainingTime.isNegative
          ? Duration(seconds: autoLoginSeconds!)
          : remainingTime;

      _animationController = AnimationController(
        vsync: this,
        duration: animationDuration,
      );
      _animation =
          Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
      _animationController.forward();
    } else {
      // No animation needed - create a dummy controller that doesn't animate
      _animationController = AnimationController(
        vsync: this,
        duration: Duration.zero,
      );
      _animation =
          Tween<double>(begin: 1.0, end: 1.0).animate(_animationController);
      final enableLogin = widget.widgetData?['enable_login'] ?? false;
      if (enableLogin) {
        acceptButtonFg = AppColors.g40; // Normal green button
        acceptButtonBg = AppColors.g40; // Same color, no animation
      } else {
        acceptButtonFg = Color(0xffEAEAF1);
        acceptButtonBg = Color(0xffEAEAF1);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginSelfieProvider =
        Provider.of<LoginSelfieProvider>(context, listen: false);

    return Expanded(
      flex: 1,
      child: Container(
        color: AppColors.n0,
        padding: EdgeInsets.symmetric(
          vertical: 16.h,
          horizontal: 36.w,
        ),
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : Row(
                children: [
                  if (autoLoginEnabled == true) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.n60),
                        ),
                        onPressed: () async {
                          // Cancel auto-login functionality
                          setState(() {
                            _isLoading = true;
                          });
                          try {
                            await RunnerHttp.cancelAutoLogin();
                            // Refresh the view by calling runner state API
                            if (context.mounted) {
                              final runnerRtDataProvider =
                                  Provider.of<RunnerRtDataProvider>(context,
                                      listen: false);
                              await runnerRtDataProvider.fetchDataNow();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showSnackbar(context, "Something went wrong");
                            }
                          } finally {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        },
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.n90),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.widgetData?['enable_login']
                          ? () async {
                              if (_isNavigating) return;
                              _isNavigating = true;

                              final loginCtaProps = <String, dynamic>{
                                'timestamp':
                                    DateTime.now().toUtc().toIso8601String(),
                                'auto_login_enabled':
                                    widget.widgetData?['auto_login_enabled'] ==
                                        true,
                              };
                              MixpanelSetup.logEvent(
                                  TrackingEvents.loginCtaClick, loginCtaProps);

                              final position = await fetchCurrentLocation();
                              final loginSelfie = LoginSelfie.fromMap(
                                {
                                  'lat': position?.latitude,
                                  'lng': position?.longitude,
                                },
                              );
                              loginSelfieProvider.selfie = loginSelfie;
                              if (context.mounted) {
                                Navigator.of(context)
                                    .pushNamed(SelfieForLogin.routeName)
                                    .then((_) async {
                                  if (context.mounted) {
                                    final runnerRtDataProvider =
                                        Provider.of<RunnerRtDataProvider>(
                                            context,
                                            listen: false);
                                    await runnerRtDataProvider.fetchDataNow();
                                  }
                                });
                              }
                              await ClevertapSetup.logEvent(
                                  TrackingEvents.jobLoginLoginButtonClicked, {
                                "action": "job login button clicked",
                              });

                              _isNavigating = false;
                            }
                          : null,
                      child: SizedBox(
                        height: 46.h,
                        child: Stack(
                          children: [
                            // Red background (revealed as green overlay shrinks)
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                        color: acceptButtonBg,
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: 1.0 - _animation.value,
                                      heightFactor: 1.0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8.r),
                                          color: acceptButtonFg,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            // Text + optional CTA badge — reacts to provider.
                            Center(
                              child: Consumer<RunnerRtDataProvider>(
                                builder: (context, rt, _) {
                                  final loginCta = rt.ctaOverrideMap['login'];
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Login',
                                        style: TextStyle(
                                          color:
                                              widget.widgetData?['enable_login']
                                                  ? Colors.white
                                                  : AppColors.n60,
                                        ),
                                      ),
                                      if (loginCta != null) ...[
                                        SizedBox(width: 8.w),
                                        CtaBadgeChip(cta: loginCta),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

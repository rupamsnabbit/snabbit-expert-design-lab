// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/selfie_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/job_login/sefie_error.dart';

import '../../services/runner_http.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/services/gamification/post_action_overlay_controller.dart';

class SelfiePreview extends StatefulWidget {
  static const routeName = "selfie-preview";
  final XFile? buildingGatePhoto;

  const SelfiePreview({super.key, this.buildingGatePhoto});

  @override
  State<SelfiePreview> createState() => _SelfiePreviewState();
}

class _SelfiePreviewState extends State<SelfiePreview> {
  bool init = true;
  bool loading = true;
  bool loginloading = false;
  String? error;
  late RunnerRtDataProvider runnerRtDataProvider;
  late LoginSelfieProvider loginSelfieProvider;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late LoginSelfie loginSelfie;

  Future<void> initProcess() async {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      loginSelfieProvider =
          Provider.of<LoginSelfieProvider>(context, listen: true);

      loginSelfie = loginSelfieProvider.selfie ?? LoginSelfie();

      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size(double.infinity, 100.h),
        child: CommonAppBar(
          title: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: widget.buildingGatePhoto != null ? 0 : 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 8.h,
                ),
                Text(
                  widget.buildingGatePhoto != null
                      ? languageProvider.getMessage("photo_building_gate",
                          "Take a photo of the building gate")
                      : userProfileProvider.user?.alternateDeliveryMethod ==
                              AlternateDeliveryMethod.yulu
                          ? languageProvider.getMessage("take_selfie_bike",
                              "Take a selfie with your bike")
                          : languageProvider.getMessage(
                              "take_selfie", "Take a selfie"),
                  style: TextStyle(
                      color: const Color(0xFF101840),
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.buildingGatePhoto != null
                      ? languageProvider.getMessage("main_gate_visible",
                          "Please make sure the main gate is properly visible")
                      : userProfileProvider.user?.alternateDeliveryMethod ==
                              AlternateDeliveryMethod.yulu
                          ? languageProvider.getMessage("helmet_visible",
                              "Please make sure to wear your helmet")
                          : languageProvider.getMessage("uniform_visible",
                              "Make sure your uniform is clearly visible"),
                  style: TextStyle(
                    color: const Color(0xFF101840),
                    fontSize: 11.sp,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: (widget.buildingGatePhoto != null ||
                      loginSelfie.selfie != null)
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(3.14), // Horizontal flip
                      child: AspectRatio(
                        aspectRatio: 0.5625,
                        child: Image.file(
                          File(widget.buildingGatePhoto != null
                              ? widget.buildingGatePhoto!.path
                              : loginSelfie.selfie!.path),
                        ),
                      ),
                    )
                  : const SizedBox(), // Show empty widget if no image available
            ),
            SizedBox(
              height: 130.h,
              child: loginloading
                  ? CupertinoActivityIndicator(
                      color: AppColors.g40,
                      radius: 24.r,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: (MediaQuery.of(context).size.width * 0.36).w,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEAEAF1),
                              ),
                              child: Text(
                                languageProvider.getMessage("retake", "Retake"),
                                style: const TextStyle(
                                    fontSize: 15, color: Color(0xFF101840)),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: (MediaQuery.of(context).size.width * 0.36).w,
                            child: ElevatedButton(
                              onPressed: widget.buildingGatePhoto != null
                                  ? () {
                                      setState(() {
                                        loginloading = true;
                                      });
                                      multiPartUpload();
                                    }
                                  : () async {
                                      setState(() {
                                        loginloading = true;
                                      });
                                      multiPartUpload().then((_) {
                                        if (error != AppStrings.retakeSelfie) {
                                          showModalBottomSheet(
                                            context: context,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                top: Radius.circular(16.r),
                                              ),
                                            ),
                                            builder: (context) {
                                              return ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  minHeight:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .height *
                                                          0.4,
                                                  maxHeight:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .height *
                                                          0.4,
                                                ),
                                                child: Center(
                                                  child: error == null
                                                      ? Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .check_circle_rounded,
                                                              color:
                                                                  AppColors.g40,
                                                              size: 48,
                                                            ),
                                                            SizedBox(
                                                                height: 24.h),
                                                            Text(
                                                              languageProvider
                                                                  .getMessage(
                                                                      "login_successful",
                                                                      "Login successful"),
                                                              style: TextStyle(
                                                                  fontSize:
                                                                      20.sp,
                                                                  color: const Color(
                                                                      0xFF101840)),
                                                            )
                                                          ],
                                                        )
                                                      : Text(error.toString()),
                                                ),
                                              );
                                            },
                                          );
                                        }
                                      }).onError((e, stacktrace) {
                                        setState(() {
                                          loginloading = false;
                                        });
                                        showSnackbar(
                                            context, "Error occurred.");
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                              ),
                              child: Text(
                                languageProvider.getMessage("submit", "Submit"),
                                style: const TextStyle(
                                    fontSize: 15, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> multiPartUpload() async {
    Response? response;
    if (widget.buildingGatePhoto != null) {
      response = await RunnerHttp.markArrival(
          widget.buildingGatePhoto?.path, runnerRtDataProvider.jobId);
    } else {
      response = await RunnerHttp.shiftLogin(loginSelfie);
    }
    if (widget.buildingGatePhoto != null) {
      await ClevertapSetup.logEvent(TrackingEvents.buildingGatePhotoSubmitted, {
        "action": "building gate photo submitted",
      });
    } else {
      await ClevertapSetup.logEvent(TrackingEvents.selfieSubmitted, {
        "action": "selfie submitted",
      });
    }
    if (response?.statusCode == 200) {
      setState(() {
        loginloading = false;
      });
      // [PartnerHome] will resumePolling then poll — do not fetch here: current_state
      // often still returns RUNNER_LOGIN_* for a short window right after shift/login.
      if (widget.buildingGatePhoto == null) {
        runnerRtDataProvider.markPendingPostLoginStatePoll();
      }

      final postActionOutcome = widget.buildingGatePhoto == null
          ? PostActionOverlayController.parseFromResponse(
              response?.data, LifecycleActionType.earlyLogin)
          : null;

      Future.delayed(widget.buildingGatePhoto != null ? 900.ms : 1800.ms, () {
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil(PartnerHome.routeName, (route) => false);

        // Show post-action animation after PartnerHome has built.
        if (postActionOutcome != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            PostActionOverlayController.instance.show(postActionOutcome);
          });
        }
      });
    } else {
      try {
        final resError = ResponseError.fromMap(response?.data);
        if (resError.errors?.isNotEmpty == true) {
          final selfieError = resError.errors?.where(
            (element) => element.errorMessageCode == AppStrings.retakeSelfie,
          );
          if (selfieError?.isNotEmpty == true) {
            List<String> errors =
                (selfieError?.first.data as List).cast<String>();
            setState(() {
              error = selfieError?.first.errorMessageCode;
              loginloading = false;
            });
            showSelfieError(errors, context);
          } else {
            setState(() {
              error = resError.errors?.first.message;
              loginloading = false;
            });
          }
        } else {
          setState(() {
            "Something went wrong (${response?.statusCode}) - ${GlobalState().appError.value.description ?? ""}";
            loginloading = false;
          });
        }
      } catch (e) {
        setState(() {
          error =
              "Something went wrong - ${GlobalState().appError.value.description ?? ""}";
          loginloading = false;
        });
      }
    }
  }
}

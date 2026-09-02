import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/referral.dart';
import '../referrals/services/referral_http.dart';
import '../referrals/widgets/earned_referral_summary.dart';
import '../referrals/widgets/referral_status_view.dart';
import '../referrals/widgets/referral_tick.dart';

class ReferralProgressSteps extends StatefulWidget {
  final RunnerReferral currentReferral;

  const ReferralProgressSteps({super.key, required this.currentReferral});

  @override
  State<ReferralProgressSteps> createState() => _ReferralProgressStepsState();
}

class _ReferralProgressStepsState extends State<ReferralProgressSteps> {
  bool init = true;
  late LanguageProvider languageProvider;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 27.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.currentReferral.name ?? "",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xff40515B),
                        ),
                  ),
                  if (widget.currentReferral.phone != null)
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Text(
                        widget.currentReferral.phone ?? "",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11.sp,
                              color: const Color(0xff40515B),
                            ),
                      ),
                    ),
                ],
              ),
            ),
            if (![
              ReferralStatus.completed,
              ReferralStatus.paid,
              ReferralStatus.failed,
              ReferralStatus.didNotJoin,
              ReferralStatus.droppedOut
            ].contains(widget.currentReferral.statusData?.status))
              Row(
                children: [
                  SizedBox(
                    height: 40.r,
                    width: 40.r,
                    child: OutlinedButton(
                      onPressed: () async {
                        final response = await ReferralHttp.remind(data: {
                          "referrals": [
                            {
                              "referral_name": widget.currentReferral.name,
                              "referral_phone_number":
                                  widget.currentReferral.phone,
                            },
                          ]
                        });
                        if (context.mounted) {
                          showSnackbar(context, "Reminder sent");
                          Navigator.of(context).pop();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.n90,
                        side: const BorderSide(color: AppColors.n40),
                        padding: EdgeInsets.zero,
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Icon(
                          Icons.notifications_active_outlined,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  SizedBox(
                    height: 40.r,
                    width: 40.r,
                    child: OutlinedButton(
                      onPressed: () async {
                        final phone = widget.currentReferral.phone ?? '';
                        if(phone.trim().isNotEmpty){
                          await CallUtils.handleCallInitiation(
                              phoneNumber: phone,
                              context: context,
                              callSourceLabel: "REFERRAL_PROGRESS_STEPS",);
                        }

                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.n90,
                        side: const BorderSide(color: AppColors.n40),
                        padding: EdgeInsets.zero,
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Icon(
                          Icons.call,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Divider(
            height: 1.h,
            color: AppColors.n20,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 11.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  languageProvider.getMessage(
                    'referral_status',
                    'Referral Status',
                  ),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              RunnerReferralStatusWidget(
                currentReferral: widget.currentReferral,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.currentReferral.referralSteps.map(
            (e) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.order != 1)
                    Container(
                      margin: EdgeInsets.only(left: 11.r),
                      height: 16.h,
                      width: 1.w,
                      color: AppColors.n30,
                    ),
                  Row(
                    children: [
                      if (e.referralStepStatus == ReferralStepStatus.completed)
                        const ReferralTick(
                          height: 22,
                        )
                      else if (e.referralStepStatus ==
                          ReferralStepStatus.failed)
                        Container(
                          height: 22.r,
                          width: 22.r,
                          decoration: const BoxDecoration(
                            color: AppColors.r40,
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all(3.r),
                          child: const FittedBox(
                            child: Icon(
                              Icons.close_rounded,
                              color: AppColors.n0,
                            ),
                          ),
                        )
                      else if ([
                            ReferralStepStatus.pending,
                            ReferralStepStatus.inProgress
                          ].contains(e.referralStepStatus) &&
                          (e.maxValue ?? 0) > 0)
                        SizedBox(
                          width: 22.r,
                          height: 22.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.r,
                            strokeCap: StrokeCap.round,
                            value: (e.currentValue ?? 0) / e.maxValue!,
                            color: AppColors.y50,
                            backgroundColor: AppColors.y10,
                          ),
                        )
                      else
                        Container(
                          height: 22.r,
                          width: 22.r,
                          decoration: BoxDecoration(
                            color: AppColors.n0,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.n30),
                          ),
                        ),
                      SizedBox(width: 5.w),
                      Expanded(
                        child: CustomText(
                          textData: e.title,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      if ((e.amount ?? 0) > 0 &&
                          e.referralStepStatus == ReferralStepStatus.completed)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 6.5.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1000.r),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              transform: GradientRotation(355 * 3.1416 / 180),
                              colors: [
                                Color(0xFF696FCC), // #696FCC
                                Color(0xFF424792), // #424792
                              ],
                              stops: [0.0286, 0.7634], // 2.86% and 76.34%
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RemoteImageHandler(
                                imageUrl:
                                    "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/referrals/rupee_coin.png",
                                height: 23.h,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                "+₹${e.amount}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.n0),
                              ),
                            ],
                          ),
                        )
                      else if ((e.amount ?? 0) > 0)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 6.5.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1000.r),
                            color: const Color(0xffEAEAF1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RemoteImageHandler(
                                imageUrl:
                                    "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/referrals/rupee_coin_disabled.png",
                                height: 23.h,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                "+₹${e.amount}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.n60),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ).toList(),
        ),
        if (widget.currentReferral.bonusSummary != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: EarnedReferralSummary(
              currentReferral: widget.currentReferral,
            ),
          ),
        Container(
          width: 1.sw,
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              languageProvider.getMessage(
                "ok_got_it",
                "Okay, got it",
              ),
            ),
          ),
        ),
      ],
    );
  }
}

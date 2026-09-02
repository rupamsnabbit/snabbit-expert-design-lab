import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/leave_model.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/runner_leave_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/elevated_button_with_loader.dart';
import 'package:snabbit_runner/widgets/long_leave/leave_cancelled.dart';
import 'package:snabbit_runner/widgets/long_leave/leave_denied.dart';
import 'package:snabbit_runner/widgets/long_leave/leave_pending.dart';
import 'package:snabbit_runner/widgets/long_leave/leave_reason.dart';
import 'package:snabbit_runner/widgets/long_leave/leave_submitted.dart';
import 'package:snabbit_runner/widgets/support_popup.dart';

import '../../utils/constants.dart';
import '../common_bottomsheet_setup.dart';
import '../long_leave/apply_for_leave.dart';
import '../long_leave/leave_approved.dart';

class LongLeaveApplication extends StatefulWidget {
  static const String routeName = '/long-leave';

  const LongLeaveApplication({super.key});

  @override
  State<LongLeaveApplication> createState() => _LongLeaveApplicationState();
}

class _LongLeaveApplicationState extends State<LongLeaveApplication> {
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late LeaveApplicationData leaveApplicationData;
  UserProfile? userProfile;

  // bool isError = false;
  bool init = true;
  ScrollController leavesScrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      leaveApplicationData =
          Provider.of<LeaveApplicationData>(context, listen: true);
      userProfile = userProfileProvider.user;
      init = false;
      leavesScrollController.addListener(_scrollListener);
      Future(() {
        getLeaves();
      });
    }
  }

  void getLeaves() {
    leaveApplicationData.reset();
    leaveApplicationData.getAllLeaveApplications();
  }

  void _scrollListener() {
    if (leavesScrollController.position.pixels >=
        leavesScrollController.position.maxScrollExtent * 0.9) {
      if (!leaveApplicationData.loading && leaveApplicationData.hasMore) {
        leaveApplicationData.getAllLeaveApplications(
            cursor: leaveApplicationData.leaveResponse?.nextPage);
      }
    }
  }

  void onTapLeaveTile(LeaveApplication? application) {
    leaveApplicationData.resetLeaveApplicationParams();
    leaveApplicationData.updateCurrentLeaveApplication(application);
    if (application?.status == "PENDING") {
      leaveApplicationData
          .updateLeaveApplicationStep(LeaveApplicationStep.leavePending);
      openLeaveApplicationBottomSheet();
    } else if (application?.status == "APPROVED") {
      leaveApplicationData
          .updateLeaveApplicationStep(LeaveApplicationStep.leaveApproved);
      openLeaveApplicationBottomSheet();
    } else if (application?.status == "CANCELLED") {
      leaveApplicationData
          .updateLeaveApplicationStep(LeaveApplicationStep.leaveCancelled);
      openLeaveApplicationBottomSheet();
    } else {
      leaveApplicationData
          .updateLeaveApplicationStep(LeaveApplicationStep.leaveDenied);
      openLeaveApplicationBottomSheet();
    }
  }

  String applicationTileHeader(LeaveApplication? application) {
    String val = languageProvider.getMessage(
      "applied",
      "Applied",
    );
    try {
      if (application?.createdAt != null) {
        val += ": ";
        val += DateFormat("EEEE").format(application!.createdAt!);
        val += ", ";
        val += formatSingleDateShortMonth(application.createdAt);
      }
    } catch (e) {
      // DO NOTHING
    }
    return val;
  }

  @override
  void dispose() {
    leavesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        elevation: 8.h,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.n70),
            ),
            onPressed: () async {
              showModalBottomNeedHelp();
            },
            child: Row(
              children: [
                const Icon(Icons.phone, color: AppColors.n70),
                SizedBox(width: 5.w),
                Text(
                  languageProvider.getMessage("help", "Help"),
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: AppColors.n70),
                ),
              ],
            ),
          ),
          IconButton(onPressed: () {
            getLeaves();
          }, icon: Icon(Icons.refresh_rounded, color: AppColors.n90,),),
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(8.r),
        width: 1.sw,
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.r),
          ),
          elevation: 4.h,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: 22.h,
                  bottom: 20.h,
                ),
                child: Text(
                    languageProvider.getMessage(
                      "your_leave_applications",
                      "Your leave applications",
                    ),
                    style: Theme.of(context).textTheme.headlineLarge),
              ),
              if (leaveApplicationData.leaveRequests != null &&
                  leaveApplicationData.leaveRequests!.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    controller: leavesScrollController,
                    shrinkWrap: true,
                    itemCount: leaveApplicationData.leaveRequests?.length ?? 0,
                    itemBuilder: (context, index) {
                      LeaveApplication? application =
                          leaveApplicationData.leaveRequests?[index];
                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              left: 14.w,
                              right: 10.w,
                            ),
                            child: InkWell(
                              onTap: () {
                                onTapLeaveTile(application);
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 64.r,
                                    height: 64.r,
                                    decoration: BoxDecoration(
                                      color: AppColors.n30,
                                      borderRadius: BorderRadius.circular(16.r),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${getLeaveDuration(application?.startDate, application?.endDate) ?? "--"}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w800),
                                        ),
                                        Text(
                                          languageProvider.getMessage(
                                            "days",
                                            "DAYS",
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(color: AppColors.n70),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formatDateRange(
                                              application?.startDate,
                                              application?.endDate),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium,
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          applicationTileHeader(application),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(color: AppColors.n80),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  LeaveStatus(
                                    languageProvider: languageProvider,
                                    application: application,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.w,
                              vertical: 8.h,
                            ),
                            child: const Divider(
                              color: AppColors.n30,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              if (leaveApplicationData.loading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: const CupertinoActivityIndicator(),
                )
              else if (leaveApplicationData.leaveRequests?.isEmpty ?? true)
                Expanded(
                  child: Center(
                    child: Text(
                        languageProvider.getMessage(
                          "no_leave_applications",
                          "No leave applications found",
                        ),
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 12.h, right: 12.w),
        child: FloatingActionButton(
          onPressed: () {
            leaveApplicationData.resetLeaveApplicationParams();
            openLeaveApplicationBottomSheet();
          },
          backgroundColor: AppColors.brand,
          child: const Icon(
            Icons.add,
            color: AppColors.n0,
          ),
        ),
      ),
    );
  }

  void openLeaveApplicationBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return const LeaveApplicationPopup();
      },
    );
  }

  void showModalBottomNeedHelp() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return const CommonBottomSheetSetup(
          child: SupportPopup(),
        );
      },
    );
  }
}

class LeaveStatusSubtitle extends StatelessWidget {
  final LanguageProvider languageProvider;
  final LeaveApplication? application;

  const LeaveStatusSubtitle({
    super.key,
    required this.languageProvider,
    required this.application,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      application?.status == "PENDING"
          ? languageProvider.getMessage(
              "leave_under_review_short",
              "Leave application under review",
            )
          : application?.status == "APPROVED"
              ? languageProvider.getMessage(
                  'leave_approved_short',
                  "Leave approved",
                )
              : application?.status == "REJECTED"
                  ? languageProvider.getMessage(
                      'leave_rejected_short',
                      "Leave rejected",
                    )
                  : application?.status == "CANCELLED"
                      ? languageProvider.getMessage(
                          'leave_cancelled_short',
                          "Leave cancelled",
                        )
                      : "",
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(color: AppColors.n60, fontSize: 11.sp),
    );
  }
}

class LeaveStatus extends StatelessWidget {
  final LanguageProvider languageProvider;
  final LeaveApplication? application;

  const LeaveStatus({
    super.key,
    required this.languageProvider,
    required this.application,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.n30;
    Color textColor = AppColors.n50;
    String? svgAsset;

    switch (application?.status) {
      case "APPROVED":
        bgColor = AppColors.g10;
        textColor = AppColors.g50;
        svgAsset = "assets/svgs/drawer/long-leave/approved.svg";
        break;
      case "REJECTED":
      case "CANCELLED":
        bgColor = AppColors.r10;
        textColor = AppColors.r50;
        svgAsset = "assets/svgs/drawer/long-leave/rejected.svg";
        break;
      case "PENDING":
        bgColor = AppColors.y10;
        textColor = AppColors.y50;
        svgAsset = "assets/svgs/drawer/long-leave/pending.svg";
        break;
      default:
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 4.h,
        horizontal: 6.w,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Row(
        children: [
          svgAsset != null
              ? SvgPicture.asset(
                  svgAsset,
                )
              : Container(),
          SizedBox(width: 2.w),
          Text(
            languageProvider.getMessage("${application?.status?.toLowerCase()}",
                application?.status?.toUpperCase() ?? ""),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: textColor,
                ),
          ),
        ],
      ),
    );
  }
}

class LeaveApplicationPopup extends StatefulWidget {
  const LeaveApplicationPopup({super.key});

  @override
  State<LeaveApplicationPopup> createState() => _LeaveApplicationPopupState();
}

class _LeaveApplicationPopupState extends State<LeaveApplicationPopup> {
  bool init = true;
  late LeaveApplicationData leaveApplicationData;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      leaveApplicationData =
          Provider.of<LeaveApplicationData>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  Widget getWidgetBasedOnCurrentStep() {
    switch (leaveApplicationData.leaveApplicationStep) {
      case LeaveApplicationStep.applyForLeave:
        return const ApplyForLeave();
      case LeaveApplicationStep.leaveReason:
        return const LeaveReason();
      case LeaveApplicationStep.leaveSubmitted:
        return const LeaveSubmitted();
      case LeaveApplicationStep.leavePending:
        return const LeavePending();
      case LeaveApplicationStep.leaveDenied:
        return const LeaveDenied();
      case LeaveApplicationStep.leaveCancelled:
        return const LeaveCancelled();
      case LeaveApplicationStep.cancelConfirmation:
        return const LeaveCancelConfirmation();
      case LeaveApplicationStep.leaveApproved:
        return const LeaveApproved();
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: CommonBottomSheetSetup(
        child: getWidgetBasedOnCurrentStep(),
      ),
    );
  }
}

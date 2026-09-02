import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/check_in_without_otp/views/check_in_location_error.dart';
import 'package:snabbit_runner/widgets/check_in_without_otp/views/check_in_phone_number_error.dart';
import 'package:snabbit_runner/widgets/check_in_without_otp/views/check_in_without_otp_phone_entry_view.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/job_start_flow/checkin_confirmed.dart';
import '../models/failure_type.dart';
import '../models/check_in_without_otp_bottom_sheet_view.dart';
import '../providers/check_in_without_otp_provider.dart';
import '../services/check_in_without_otp_service.dart';

/// Presents the verify check-in phone bottom sheet.
///
/// The provider is created specifically for this bottom sheet instance.
Future<T?> showCheckInWithoutOtpBottomSheet<T>(
  BuildContext context,
) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider<CheckInWithoutOtpProvider>(
      create: (_) => CheckInWithoutOtpProvider(),
      child: const CheckInWithoutOtpBottomSheet(),
    ),
  ).then(
    (value) {
      if(context.mounted) {
        final provider = context.read<RunnerRtDataProvider>();
        provider.fetchDataNow();
      }
      ClevertapSetup.logEvent(TrackingEvents.checkInWithoutOtpBottomSheetDismissed, {});
      return null;
    },
  );
}

/// Bottom sheet that verifies check-in using the booking phone number.
///
/// The sheet switches its internal content based on the provider view state.
class CheckInWithoutOtpBottomSheet extends StatefulWidget {
  /// Creates the bottom sheet widget.
  const CheckInWithoutOtpBottomSheet({super.key});

  @override
  State<CheckInWithoutOtpBottomSheet> createState() =>
      _CheckInWithoutOtpBottomSheetState();
}

class _CheckInWithoutOtpBottomSheetState
    extends State<CheckInWithoutOtpBottomSheet> {

  /// Provider reference initialized from the widget tree.
  late CheckInWithoutOtpProvider _provider;
  late RunnerRtDataProvider _runnerRtDataProvider;

  /// Guards one-time provider initialization in `didChangeDependencies`.
  bool _isInitDone = false;

  @override
  void initState() {
    super.initState();
    ClevertapSetup.logEvent(TrackingEvents.checkInWithoutOtpBottomSheetDisplayed, {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<CheckInWithoutOtpProvider>(context);
    _runnerRtDataProvider = Provider.of<RunnerRtDataProvider>(context);
    if (!_isInitDone) {
      _provider.init(
          service: CheckInWithoutOtpService(),
          jobId: _runnerRtDataProvider.jobId ?? 0);
      _isInitDone = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(
                Icons.close,
                color: AppColors.n0,
                size: 21.r,
              ),
            )
          ],
        ),
        CommonBottomSheetSetup(
          bgColor: AppColors.n0,
          horizontalPadding: 0,
          bottomPadding: 28,
          showDragHandle: false,
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: true,
            child: Consumer<CheckInWithoutOtpProvider>(
              builder: (context, provider, _) {
                switch (provider.view) {
                  case CheckInWithoutOtpBottomSheetView.enterPhoneNumber:
                    return CheckInWithoutOtpPhoneEntryView();
                  case CheckInWithoutOtpBottomSheetView.loading:
                    return const _LoadingView();
                  case CheckInWithoutOtpBottomSheetView.success:
                    return CheckInConfirmed();
                  case CheckInWithoutOtpBottomSheetView.failure:
                    return const _FailurePlaceholderView();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Loading view shown while verification is in progress.
class _LoadingView extends StatelessWidget {
  /// Creates the loading view.
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, languageProvider, _) {
      return Container(
        width: 1.sw,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 24.h),
            Text(
              '${languageProvider.getMessage('verifying', 'Verifying')}...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.n90,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            const CircularProgressIndicator(),
            SizedBox(height: 24.h),
          ],
        ),
      );
    });
  }
}

/// Placeholder failure UI. Replace with the real design later.
class _FailurePlaceholderView extends StatelessWidget {
  /// Creates the failure placeholder view.
  const _FailurePlaceholderView();

  @override
  Widget build(BuildContext context) {
    return Consumer2<CheckInWithoutOtpProvider, LanguageProvider>(
        builder: (context, verifyCheckInPhoneProvider, languageProvider, _) {
      switch (verifyCheckInPhoneProvider.errorResponse?.failureType) {
        case FailureType.location:
          return CheckInWithoutOtpLocationError();
        case FailureType.phoneNumber:
          return CheckInWithoutOtpPhoneNumberError();
        default:
          return SizedBox(
            height: 180.h,
            child: Center(
              child: Text(
                languageProvider.getMessage('failed_to_check_in_without_otp',
                    "Failed to Check in without OTP"),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.r40,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          );
      }
    });
  }
}

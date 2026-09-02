import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';

import '../../providers/referral.dart';

class RunnerReferralStatusWidget extends StatefulWidget {
  final RunnerReferral currentReferral;

  const RunnerReferralStatusWidget({
    super.key,
    required this.currentReferral,
  });

  @override
  State<RunnerReferralStatusWidget> createState() =>
      _RunnerReferralStatusWidgetState();
}

class _RunnerReferralStatusWidgetState
    extends State<RunnerReferralStatusWidget> {
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
    switch (widget.currentReferral.statusData?.status) {
      case ReferralStatus.pending:
      case ReferralStatus.inProgress:
        return ReferralStatusView(
          text: languageProvider.getMessage(
            "in_progress",
            "In progress",
          ),
          bgColor: AppColors.y10,
          textColor: AppColors.y50,
        );
      case ReferralStatus.completed:
      case ReferralStatus.paid:
        return ReferralStatusView(
          text: languageProvider.getMessage(
            "completed",
            "Completed",
          ),
          bgColor: AppColors.g10,
          textColor: AppColors.g50,
        );
      case ReferralStatus.failed:
      case ReferralStatus.droppedOut:
      case ReferralStatus.didNotJoin:
        return ReferralStatusView(
          text: languageProvider.getMessage(
            "unsuccessful",
            "Unsuccessful",
          ),
          bgColor: AppColors.r10,
          textColor: AppColors.r50,
        );
      default:
        return const SizedBox();
    }
  }
}

class ReferralStatusView extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const ReferralStatusView({
    super.key,
    required this.text,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.r),
        color: bgColor,
      ),
      child: Text(
        text,
        style:
            Theme.of(context).textTheme.labelMedium?.copyWith(color: textColor),
      ),
    );
  }
}

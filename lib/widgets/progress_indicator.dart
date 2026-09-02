import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';

class ProgressIndicatorAtTop extends StatefulWidget {
  @Deprecated("Not required anymore")
  final int? value;

  const ProgressIndicatorAtTop({
    super.key,
    this.value,
  });

  @override
  State<ProgressIndicatorAtTop> createState() => _ProgressIndicatorAtTopState();
}

class _ProgressIndicatorAtTopState extends State<ProgressIndicatorAtTop> {
  bool init = true;
  late UserProfileProvider userProfileProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: LinearProgressIndicator(
        value: (userProfileProvider.user?.registrationStep?.currentValue ?? 0) /
            (userProfileProvider.user?.registrationStep?.total ?? 1),
        backgroundColor: Colors.grey[200],
        minHeight: 7,
        borderRadius: BorderRadius.circular(8),
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
      ),
    );
  }
}

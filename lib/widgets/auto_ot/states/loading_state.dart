import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import '../../../utils/colors.dart';

/// Loading state widget for Auto-OT bottom sheet
///
/// Displays a loading indicator while the API call is in progress.
class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Container(
          width: 393.w,
          height: 300.h,
          decoration: const BoxDecoration(
            color: AppColors.n0,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(
                  radius: 20,
                ),
                SizedBox(height: 24.h),
                Text(
                  "${languageProvider.getMessage('please_wait', 'Please wait')}...",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

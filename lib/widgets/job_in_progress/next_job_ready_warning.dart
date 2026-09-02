import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart'; // For responsive sizing

class NextJobReadyWarning extends StatelessWidget {
  const NextJobReadyWarning({
    super.key,
  });


  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
        return Container(
          padding: EdgeInsets.all(12.w),
          // Figma: padding: 12px;
          decoration: BoxDecoration(
            // Figma: background: #FDF4F4;
            color: AppColors.r0,
            borderRadius: BorderRadius.circular(8.r), // Figma: border-radius: 8px;
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            // Figma: align-items: center;
            children: [
              // Warning Icon (Placeholder as requested)
              // Figma: width: 20px; height: 18.1px;
              Container(
                width: 20.w,
                height: 18.1.h,
                alignment: Alignment.center,
                child: Image.asset(AssetConstants.fpWarningPng),
              ),
              SizedBox(width: 12.w), // Figma: gap: 12px;

              // Warning Text
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    languageProvider.getMessage("next_job_ready_warning",
                        "Next job is ready. Check out to accept."),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          height: 16 / 14, // Figma: line-height: 16px;
                          letterSpacing:
                              -0.24.sp, // Figma: letter-spacing: -0.24px;
                          color: AppColors.r50, // Figma: color: #A73636; (Red/R50)
                        ),
                    overflow: TextOverflow.ellipsis, // Handle long text
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

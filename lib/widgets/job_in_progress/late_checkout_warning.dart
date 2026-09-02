import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart'; // For responsive sizing

class LateCheckoutWarning extends StatelessWidget {
  const LateCheckoutWarning({super.key});

  @override
  Widget build(BuildContext context) {

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Container(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 12.w, 12.h), // Figma: padding: 12px 12px 12px 16px;
          decoration: BoxDecoration(
            // Figma: background: linear-gradient(90deg, #FFC0B1 0%, #FF8B8B 100%);
            gradient: const LinearGradient(
              begin: Alignment.centerLeft, // 90deg
              end: Alignment.centerRight,
              colors: [
                Color(0xFFFFC0B1), // #FFC0B1
                Color(0xFFFF8B8B), // #FF8B8B
              ],
            ),
            borderRadius: BorderRadius.circular(8.r), // Figma: border-radius: 8px 8px 0px 0px;
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center, // Figma: align-items: center;
            children: [
              // Warning Icon (Placeholder as requested)
              // Figma: width: 53.5px; height: 50.16px;
              SizedBox(
                width: 53.5.w,
                height: 50.16.h,
                child: Image.asset(AssetConstants.fpWarningPng),
              ),
              SizedBox(width: 16.w), // Figma: gap: 16px;
        
              // Warning Text
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Figma: justify-content: center;
                  crossAxisAlignment: CrossAxisAlignment.start, // Figma: align-items: flex-start;
                  children: [
                    // "Warning!"
                    SizedBox(
                      width: 250.w, // Figma: width: 250px;
                      height: 24.h, // Figma: height: 24px;
                      child: Text(
                        languageProvider.getMessage('warning', "Warning!"),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 18.sp, // Figma: font-size: 18px;
                          height: 24 / 18, // Figma: line-height: 24px;
                          letterSpacing: -0.24.sp, // Figma: letter-spacing: -0.24px;
                          color: AppColors.r50, // Figma: color: #A73636; (Red/R50)
                        ),
                        overflow: TextOverflow.ellipsis, // Handle long text
                      ),
                    ),
                    SizedBox(height: 7.h), // Figma: gap: 7px;

                    // "Always checkout on time"
                    SizedBox(
                      width: 246.w, // Figma: width: 246px;
                      height: 16.h, // Figma: height: 16px;
                      child: Text(
                        languageProvider.getMessage('always_checkout_on_time', "Always checkout on time"),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 16.sp, // Figma: font-size: 16px;
                          height: 16 / 16, // Figma: line-height: 16px;
                          letterSpacing: -0.24.sp, // Figma: letter-spacing: -0.24px;
                          color: AppColors.r50, // Figma: color: #A73636; (Red/R50)
                        ),
                        overflow: TextOverflow.ellipsis, // Handle long text
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
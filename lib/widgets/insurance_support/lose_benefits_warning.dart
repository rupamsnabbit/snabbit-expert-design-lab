import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/insurance_profile.dart';
import 'package:snabbit_runner/providers/insurance_profile_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_text_highlighter.dart';

class LoseBenefitsWarning extends StatefulWidget {
  const LoseBenefitsWarning({super.key});

  @override
  State<LoseBenefitsWarning> createState() => _LoseBenefitsWarningState();
}

class _LoseBenefitsWarningState extends State<LoseBenefitsWarning> {
  late LanguageProvider languageProvider;
  late InsuranceProfileProvider insuranceProfileProvider;
  late UserProfileProvider userProfileProvider;
  bool isError = false;
  bool loading = false;
  bool init = true;

  Future<void> initProcess() async {
    loading=true;
    insuranceProfileProvider.fetchData();
  }


  DowngradeWarning? get downgradeWarning => insuranceProfileProvider.insuranceProfile?.qualifierInfo?.downgradeWarning;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      insuranceProfileProvider = Provider.of<InsuranceProfileProvider>(context, listen: true);
      userProfileProvider = Provider.of<UserProfileProvider>(context, listen: true);
      init = false;
      if(insuranceProfileProvider.insuranceProfile==null){
        initProcess().then((_) {
          loading = false;
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    if(loading || downgradeWarning == null) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.r10, // #F9DADA
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 85.h,
            alignment: Alignment.bottomLeft,
            child: Image.network(downgradeWarning?.image ?? '',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink(); // Placeholder for image loading error
              },
            ),
          ),
          SizedBox(width: 17.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 18.h, bottom: 18.h, right: 8.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.getFormattedMessage('downgrade_warning_title', "Don't lose {{tier}} Tier benefits",
                    {
                      'tier': userProfileProvider.user?.tier?.normalizedDescription ?? ''
                    }
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                      height: 24 / 16,
                      color: const Color(0xFFC50F1F),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  SizedBox(height: 2.h),
                  ...?downgradeWarning?.conditions?.map((condition) => Padding(
                    padding: EdgeInsets.only(bottom: 2.h),
                    child: CustomTextHighlighter(text: getMessage(condition.name??'', condition.value), customHighlighter: (text) => Text(
                      text,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),textStyle: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      height: 16 / 12,
                      color: const Color(0xFF1D2129),
                    ),),
                  ),),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getMessage(String key,dynamic value) {
    if(key== AppStrings.requiredAttendancePercentage) {
      return languageProvider.getFormattedMessage2("downgrade_warning_attendance", "Maintain {{$key}} attendance",
          {key: "${anyValueToInt(value)}%"}
      );
    } else if(key == AppStrings.requiredRating) {
      return languageProvider.getFormattedMessage2("downgrade_warning_rating", "Improve your rating to {{$key}}",
      {key: "$value+"}
      );
    } else {
      return '';
    }
  }
}

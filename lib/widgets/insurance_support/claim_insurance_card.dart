import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/insurance_profile.dart';
import 'package:snabbit_runner/pages/insurance_support.dart';
import 'package:snabbit_runner/providers/insurance_profile_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_widgets/gradient_border_container.dart';

class ClaimInsuranceCard extends StatefulWidget {
  const ClaimInsuranceCard({super.key});

  @override
  State<ClaimInsuranceCard> createState() => _ClaimInsuranceCardState();
}

class _ClaimInsuranceCardState extends State<ClaimInsuranceCard> {
  late LanguageProvider languageProvider;
  late InsuranceProfileProvider insuranceProfileProvider;
  bool isError = false;
  bool loading = false;
  bool init = true;

  Future<void> initProcess() async {
    loading=true;
    insuranceProfileProvider.fetchData();
  }

  InsuranceCoverageInfo? get insuranceCoverageInfo => insuranceProfileProvider.insuranceProfile?.tierBenefits?.insuranceCoverageInfo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      insuranceProfileProvider = Provider.of<InsuranceProfileProvider>(context, listen: true);
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
    if(loading || insuranceCoverageInfo == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        16.h,
        15.w,
        12.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.n0,
        border: Border.all(color: insuranceCoverageInfo?.borderColor ?? Colors.transparent),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            languageProvider.getMessage("insurance_coverage_title", "Insurance coverage up to"),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
              fontSize: 16.sp,
              height: 1,
              letterSpacing: -0.24,
              color: AppColors.n80, // #525871
            ),
          ),
          SizedBox(
            height: 7.h,
          ),
          // Amount
          if(insuranceCoverageInfo?.amount?.isNotEmpty==true)
          Text(
            insuranceCoverageInfo?.amount ?? '',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: -0.24,
              color: AppColors.g50, // #317159
            ),
          ),
          // Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if(insuranceCoverageInfo?.childrenAge!=null && insuranceCoverageInfo?.childrenCount!=null)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 15.h),
                  child: Text(
                    languageProvider.getFormattedMessage('dependents_insurance_coverage', 'Insurance covers your Spouse &\n{{children_count}} children having age below {{children_age}}',
                    {
                      'children_age': insuranceCoverageInfo?.childrenAge ?? '',
                      'children_count': insuranceCoverageInfo?.childrenCount ?? '',
                    }
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      height: 14 / 12,
                      // 14px line height
                      letterSpacing: -0.24,
                      color: AppColors.n70, // #696F8C
                    ),
                  ),
                ),
              )else const Spacer(),
              SizedBox(
                height: 40.h,
                child: GradientBorderContainer(
                  content: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.g40, // #429777
                      // shape: RoundedRectangleBorder(
                      //   borderRadius: BorderRadius.circular(100.r),
                      // ),
                      // padding:
                      // EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, InsuranceSupport.routeName);
                    },
                    child: FittedBox(
                      child: Text(
                        languageProvider.getMessage('claim', 'Claim'),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                          height: 18 / 16,
                          // 18px line height
                          color: AppColors.n0, // #FFFFFF
                        ),
                      ),
                    ),
                  ), borderGradient: const LinearGradient(colors: [
                    Color(0xFF317159),
                    Color(0xFFC9FFEB),
                ]),
                  radius: 100.r,
                  color: AppColors.g40,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, ),

                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

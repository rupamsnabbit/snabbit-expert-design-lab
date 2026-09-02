import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/bank_details/bank_details_modal_sheet.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_bank_or_upi_details_screen.dart';


class PayoutBankView extends StatefulWidget {
  const PayoutBankView({super.key});

  @override
  State<PayoutBankView> createState() => _PayoutBankViewState();
}

class _PayoutBankViewState extends State<PayoutBankView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.sw,
      padding: EdgeInsets.only(top: 20.h),
      child: userProfileProvider.user?.bankVerified != true
          ? GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, AddBankOrUpiDetailsScreen.routeName);
              },
              child: Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.5.r),
                    color: AppColors.r10,
                    border: Border.all(color: AppColors.r0, width: 0.9.r)),
                child: Row(
                  children: [
                    Image.asset(
                      AssetConstants.fpWarningPng,
                      height: 20.h,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getMessage(
                              'details_missing',
                              'Details Missing',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: AppColors.r50),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            languageProvider.getMessage(
                              'add_bank_details',
                              'Add bank details to avoid payment delays',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.r50),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.r50,
                      size: 25.sp,
                    ),
                  ],
                ),
              ),
            )
          : OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, AddBankOrUpiDetailsScreen.routeName);
                // showModalBottomSheet(
                //   context: context,
                //   isScrollControlled: true,
                //   constraints: BoxConstraints(
                //     maxHeight: 0.7.sh,
                //   ),
                //   builder: (ctx) {
                //     return const BankDetailsModalSheet(allowEdit: true);
                //   },
                // );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                backgroundColor: AppColors.n0,
                side: const BorderSide(color: AppColors.n40),
              ),
              child: Text(
                languageProvider.getMessage(
                  'view_bank_details',
                  'View bank details',
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';

class SlotsUnavailable extends StatefulWidget {
  final VoidCallback onOkay;
  final CustomError error;

  const SlotsUnavailable({super.key, required this.error, required this.onOkay});

  @override
  State<SlotsUnavailable> createState() => _SlotsUnavailableState();
}

class _SlotsUnavailableState extends State<SlotsUnavailable> {
  late LanguageProvider languageProvider;
  bool init = true;

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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          SizedBox(height: 8.h),
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.n90,
              borderRadius: BorderRadius.circular(100.r),
            ),
          ),
          SizedBox(height: 24.h),

          // Warning icon
          SizedBox(
            width: 70.w,
            height: 70.h,
            child: Image.asset(AssetConstants.fpWarningPng), // Replace with asset if needed
          ),
          SizedBox(height: 24.h),

          // Title
          Text(
            getTitle(),
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF000000),
            ),
            textAlign: TextAlign.center,
          ),


          // Subtitle
          if(widget.error.title==AppStrings.noSlotsAvailable)
          ...[
            SizedBox(height: 8.h),
            Text(
            languageProvider.getMessage('pls_contact_training_center', "Please contact training centre"),
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.n80,
            ),
            textAlign: TextAlign.center,
          ),],
          SizedBox(height: 24.h),

          // Okay Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: widget.onOkay,
                  child: Text(
                    languageProvider.getMessage('okay', "Okay"),
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.n0,
                      letterSpacing: -0.24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

        ],
      ),
    );
  }

  String getTitle(){
    String? title;
    switch(widget.error.title) {
      case AppStrings.noSlotsAvailable:
        title = languageProvider.getMessage('no_slots_available', "No slots available");
        break;
      case AppStrings.currentSlotUnavailable:
        title = languageProvider.getMessage('current_slots_available', "This slot is not available");
        break;
      default:
        title =widget.error.message;
    }
    return title ?? '';
  }
}
void showSlotsUnavailable(BuildContext context, CustomError error, VoidCallback onOkay,) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SlotsUnavailable(error:error,onOkay: onOkay),
    ),
  );
}

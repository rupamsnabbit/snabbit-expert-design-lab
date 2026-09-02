import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

class HeightAndWeightInformationScreen extends StatefulWidget {
  static const String routeName = "/height_and_weight_information";

  final String? title;
  final String? subTitle;
  const HeightAndWeightInformationScreen({
    super.key,
    this.title,
    this.subTitle,
  });
  @override
  State<HeightAndWeightInformationScreen> createState() =>
      _HeightAndWeightInformationScreenState();
}

class _HeightAndWeightInformationScreenState
    extends State<HeightAndWeightInformationScreen> {
  bool init = true;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  UserProfile? userProfile;
  TextEditingController heightController = TextEditingController(); //cm
  TextEditingController weightController = TextEditingController(); //kg
  List<int>? bmiRange;
  late String? title;
  late String? subTitle;

  bool get _weightHasError =>
      userProfile?.otherDetails?.weight?.isValueAcceptable() != true;

  String? getBMICriticalError() {
    final weight = userProfileProvider.user?.otherDetails?.weight?.value;
    final height = userProfileProvider.user?.otherDetails?.height?.value;
    if (weight == null ||
        height == null ||
        bmiRange == null ||
        bmiRange?.isEmpty == true) {
      return null;
    }
    final num minHeight =
        userProfile?.otherDetails?.height?.acceptedValues?.first;
    final num maxHeight =
        userProfile?.otherDetails?.height?.acceptedValues?.last;

    // Convert height from centimeters to meters
    double heightMeters = height / 100;

    // Calculate the minimum weight for the given height
    final minWeightKg = bmiRange!.first * pow(heightMeters, 2);

    // Calculate the maximum weight for the given height
    final maxWeightKg = bmiRange!.last * pow(heightMeters, 2);

    if (weight < minWeightKg || weight > maxWeightKg) {
      // Todo: check the key
      return languageProvider.getMessage(
        'bmi_not_eligible',
        "Your BMI does not meet eligibility. Please contact the Training Center Manager.",
      );
    }
    if (height < minHeight || height > maxHeight) {
      // Todo: check the key
      return languageProvider.getMessage(
        'height_not_eligible',
        "Your height does not meet eligibility. Please contact the Training Center Manager.",
      );
    }
    return null;
  }

  bool continueConditions() {
    if (userProfile?.otherDetails?.height?.value != null &&
        userProfile?.otherDetails?.weight?.value != null &&
        !_weightHasError &&
        userProfile?.otherDetails?.height?.isValueAcceptable() == true) {
      return true;
    } else {
      return false;
    }
  }

  @override
  void didChangeDependencies() {
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      if (userProfile?.otherDetails?.height?.value != null) {
        heightController.text =
            anyValueToInt(userProfile!.otherDetails!.height!.value).toString();
      }
      if (userProfile?.otherDetails?.weight?.value != null) {
        weightController.text =
            anyValueToInt(userProfile!.otherDetails!.weight!.value).toString();
      }
      bmiRange = List<int>.from(
          GlobalState().appConfig?.getCriticalField('bmi_range') ?? []);
      title = languageProvider.getMessage(
          "height_and_weight_information", "Height and Weight Information");
      subTitle = languageProvider.getMessage("height_and_weight_subtitle",
          "Please ensure all the details are accurate");
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(),
      persistentFooterButtons: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              onPressed: !userProfileProvider.loading && continueConditions()
                  ? () async {
                      await userProfileProvider
                          .runnerRegistrationAndErrorHandler(
                        context: context,
                        onError: (errorMessage) {
                          showSnackbar(
                              context, errorMessage ?? "Something went wrong");
                        },
                      );
                      if (GlobalState().canEditPermanentAddress) {
                        GlobalState().canEditPermanentAddress = false;
                      }
                      if (GlobalState().canEditDob) {
                        GlobalState().canEditDob = false;
                      }
                    }
                  : null,
              child: userProfileProvider.loading
                  ? const CupertinoActivityIndicator()
                  : Text(
                      languageProvider.getMessage(
                        'continue',
                        'Continue',
                      ),
                    ),
            ),
          ),
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 13.h),
            // Todo: Calculate the progress
            OnboardingProgressBar(
              progressValue: 0.5,
            ),
            SizedBox(height: 33.h),
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  title ?? '',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              SizedBox(height: 8.h),
            ],
            if (subTitle != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  subTitle ?? '',
                ),
              ),
              SizedBox(height: 40.h),
            ],
            OnboardingQuestion(
              questionKey: 'height',
              questionDefault: 'Height (cm)',
              mandatory: true,
              criticalError: getBMICriticalError(),
              error: userProfile?.otherDetails?.height?.isValueAcceptable() !=
                      true
                  ? "${languageProvider.getMessage(
                      'height_should_be_between',
                      "Height should be between",
                    )} ${userProfile?.otherDetails?.height?.acceptedValues?.first}"
                      " & ${userProfile?.otherDetails?.height?.acceptedValues?.last}"
                  : null,
              answer: Row(
                children: [
                  Expanded(
                    child: TextField(
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                        LengthLimitingTextInputFormatter(3),
                      ],
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter height in cm',
                        hintStyle: AppTextTheme.hintStyle,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        userProfile?.otherDetails?.height?.value =
                            double.tryParse(v);
                        userProfileProvider.notifyUserListeners();
                      },
                    ),
                  ),
                  // Todo: replace with remote image handler
                  Padding(
                    padding: EdgeInsets.only(left: 11.w),
                    child: SvgPicture.asset(AssetConstants.heightScale),
                  )
                ],
              ),
            ),
            SizedBox(
              height: 24.h,
            ),
            OnboardingQuestion(
              questionKey: 'weight',
              questionDefault: 'Weight (kgs)',
              mandatory: true,
              criticalError: getBMICriticalError(),
              error: _weightHasError
                  ? "${languageProvider.getMessage(
                      'weight_should_be_between',
                      "Weight should be between",
                    )} ${userProfile?.otherDetails?.weight?.acceptedValues?.first}"
                      " & ${userProfile?.otherDetails?.weight?.acceptedValues?.last}"
                  : null,
              answer: Row(
                children: [
                  Expanded(
                    child: TextField(
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                        LengthLimitingTextInputFormatter(3),
                      ],
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter weight in kg',
                        hintStyle: AppTextTheme.hintStyle,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        userProfile?.otherDetails?.weight?.value =
                            double.tryParse(v);
                        userProfileProvider.notifyUserListeners();
                      },
                    ),
                  ),
                  // Todo: replace with remote image handler
                  Padding(
                    padding: EdgeInsets.only(left: 11.w),
                    child: SvgPicture.asset(AssetConstants.weightScale),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

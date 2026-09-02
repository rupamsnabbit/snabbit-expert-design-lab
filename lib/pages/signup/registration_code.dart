import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/training_center.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/maps_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/registration_flow/work_schedule_selection.dart';

import '../../providers/language_provider.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/gap.dart';
import '../../widgets/onboarding_question.dart';
import '../../widgets/progress_indicator.dart';

class RegistrationCode extends StatefulWidget {
  static const String routeName = "/registration-code";

  const RegistrationCode({super.key});

  @override
  State<RegistrationCode> createState() => _RegistrationCodeState();
}

class _RegistrationCodeState extends State<RegistrationCode> {
  bool init = true;
  late UserProfileProvider userProfileProvider;
  TextEditingController registrationCodeTextController =
      TextEditingController();
  TextEditingController onboardingAgentCodeTextController =
      TextEditingController();
  late LanguageProvider languageProvider;
  List<TrainingCenter> trainingCenters = [];

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      registrationCodeTextController.text =
          userProfileProvider.user?.registrationCode ?? "";
      // userProfileProvider.user?.registrationStep =
      //     RunnerRegistrationStep.registrationCode;
      onboardingAgentCodeTextController.text =
          userProfileProvider.user?.onboardingAgentCode ?? "";
    }
    super.didChangeDependencies();
  }

  ///[canContinue] will validate the form entries for [registrationCodeTextController] and [onboardingAgentCodeTextController]
  ///and will only proceed if they contain non empty Strings
  bool canContinue() {
    bool result = false;
    try {
      result = !userProfileProvider.loading &&
          (userProfileProvider.user?.registrationCode?.trim().isNotEmpty ??
              false) &&
          (userProfileProvider.user?.onboardingAgentCode?.trim().isNotEmpty ??
              false) &&
          (userProfileProvider.user?.tc != null) &&
          (userProfileProvider.user?.workSchedule?.value != null);
    } catch (e) {
      result = false;
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  void initialize() async {
    final response = await MapsHttp.fetchTrainingCenters();

    if (response != null) {
      if (response.statusCode == 200) {
        trainingCenters = response.data
            .map<TrainingCenter>((e) => TrainingCenter.fromJson(e))
            .toList();
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.getMessage(
              "registration_details_title", "Registration Details"),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        leading: InkWell(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.n80,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProgressIndicatorAtTop(value: 1),
            Gap.gap32h,
            const OnboardingPageHeader(
              titleKey: "registration_code_title",
              titleDefault: "Registration code",
              subtitleKey: 'registration_code_subtitle',
              subtitleDefault: "Please enter the code sent",
            ),
            Gap.gap16h,
            OnboardingQuestion(
              questionKey: 'registration_code',
              questionDefault: 'Enter registration code',
              answer: TextField(
                enabled: !userProfileProvider.loading,
                controller: registrationCodeTextController,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  if (value.isEmpty) {
                    userProfileProvider.user?.registrationCode = null;
                  } else {
                    userProfileProvider.user?.registrationCode = value;
                  }
                  setState(() {});
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: languageProvider.getMessage(
                    'reg_code_hint',
                    'Enter code',
                  ),
                ),
              ),
            ),

            //TextField for onboarding agent code
            Gap.gap16h,
            OnboardingQuestion(
              questionKey: 'onboarding_agent_code',
              questionDefault: 'Enter onboarding agent code',
              answer: TextField(
                enabled: !userProfileProvider.loading,
                controller: onboardingAgentCodeTextController,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.number,
                maxLength: 10,
                onChanged: (value) {
                  if (value.isEmpty) {
                    userProfileProvider.user?.onboardingAgentCode = null;
                  } else {
                    userProfileProvider.user?.onboardingAgentCode = value;
                  }
                  setState(() {});
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: languageProvider.getMessage(
                    'agent_code_hint',
                    'Enter code',
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            OnboardingQuestion(
              questionKey: 'training_center',
              questionDefault: 'Preferred training centre location',
              answer: CustomDropdown<TrainingCenter>(
                onSelected: (val) {
                  userProfileProvider.tc = val;
                },
                hintText: languageProvider.getMessage(
                  'tc_hint',
                  'Choose one option',
                ),
                items: trainingCenters,
                selectedItem: userProfileProvider.user?.tc,
              ),
            ),
            SizedBox(height: 16.h),
            OnboardingQuestion(
              questionKey: 'work_schedule',
              questionDefault: 'Work schedule',
              criticalError: userProfileProvider
                              .user?.workSchedule?.acceptedValues?.isNotEmpty ==
                          true &&
                      userProfileProvider.user?.workSchedule?.contains(
                              userProfileProvider
                                  .user?.workSchedule?.value?.key) ==
                          true
                  ? languageProvider.getMessage(
                      'pls_review_answer_carefully',
                      "Please review this answer carefully",
                    ):null,
              answer: const WorkScheduleSelection(),
            ),
            if (userProfileProvider.error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  userProfileProvider.error!,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.r50),
                ),
              ),
          ],
        ),
      ),
      persistentFooterButtons: [
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              onPressed: !userProfileProvider.loading && canContinue()
                  ? () async {
                      await userProfileProvider
                          .runnerRegistrationAndErrorHandler(
                        context: context,
                        onError: (errorMessage) {
                          showSnackbar(
                              context, errorMessage ?? "Something went wrong");
                        },
                      );
                    }
                  : null,
              child: userProfileProvider.loading
                  ? const CupertinoActivityIndicator()
                  : Text(
                      languageProvider.getMessage(
                        'start_registration',
                        'Start Registration',
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    //disposing the text editing controllers
    registrationCodeTextController.dispose();
    onboardingAgentCodeTextController.dispose();
    super.dispose();
  }
}

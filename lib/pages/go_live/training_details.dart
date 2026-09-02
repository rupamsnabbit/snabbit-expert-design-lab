import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/go_live/training_details_data.dart';
import 'package:snabbit_runner/pages/go_live/phone_integrity_check.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/go_live_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/go_live/capsule_list.dart';
import 'package:snabbit_runner/widgets/go_live/welcome_banner.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

class TrainingDetails extends StatefulWidget {
  static const String routeName = '/training-details';

  const TrainingDetails({super.key});

  @override
  State<TrainingDetails> createState() => _TrainingDetailsState();
}

class _TrainingDetailsState extends State<TrainingDetails> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  final TextEditingController trainerCodeController = TextEditingController();
  bool init = true;
  bool loading = false;
  TrainingDetailsData? _trainingDetailsData;
  DateTime? selectedDate;
  bool invalidTrainerCode=true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      Future(() {
        initProcess();
      });
    }
    super.didChangeDependencies();
  }

  void _continue() async {
    if (trainerCodeController.text.isNotEmpty && selectedDate != null) {
      loading = true;
      setState(() {});
      try {
        final response = await GoLiveHttp.updateRunner(data: {
          'runner_id': userProfileProvider.user?.id,
          'trainer_code': trainerCodeController.text,
          'joining_date': selectedDate?.toIso8601String(),
        });
        if (response != null && response.statusCode == 200) {
          Navigator.of(context).pushNamed(PhoneIntegrityCheck.routeName);
        } else {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              showSnackbar(
                  context, responseError.errors?.firstOrNull?.message ?? '');
            },
          );
        }
        loading = false;
      } catch (_) {
        loading = false;
      }
      setState(() {});
      // Navigate to next page or update status
    }
  }

  void initProcess() async {
    //fetch items
    loading = true;
    setState(() {});
    try {
      final response =
          await GoLiveHttp.getRunnerStatus(userProfileProvider.user?.id ?? 0);
      if (response != null &&
          response.statusCode == 200 &&
          response.data != null) {
        _trainingDetailsData = TrainingDetailsData.fromJson(response.data);
        if(_trainingDetailsData!=null&&_trainingDetailsData?.trainer?.trim().isNotEmpty==true){
          trainerCodeController.text= _trainingDetailsData?.trainer ?? '';
          invalidTrainerCode=false;
        }else{
          trainerCodeController.text=languageProvider.getMessage('no_trainer_code', "No trainer code");
        }
      }else{
        trainerCodeController.text=languageProvider.getMessage('no_trainer_code', "No trainer code");
        ErrorHandler.handleResponseError(
          response: response,
          context: context,
          onError: (context, responseError) {
            showSnackbar(
                context, responseError.errors?.firstOrNull?.message ?? '');
          },
        );
      }
      loading = false;
    } catch (_) {
      loading = false;
      showSnackbar(context, "Something went wrong");
    }
    setState(() {});
  }

  bool canContinue() {
    return trainerCodeController.text.isNotEmpty && selectedDate != null && !invalidTrainerCode;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        elevation: 5.r,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage(
            "in_training",
            "In Training",
          ),
          style: textTheme.bodyLarge,
        ),
      ),
      persistentFooterButtons: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: !loading && invalidTrainerCode? initProcess: !loading && canContinue() ? _continue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                ),
                child: FittedBox(
                  child: Text(
                  invalidTrainerCode?  languageProvider.getMessage(
                    "retry",
                    "Retry",
                  ):languageProvider.getMessage(
                      "proceed",
                      "Proceed",
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      body: init || loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 23.h,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.n0,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: const WelcomeBanner(),
                    ),
                    // Trainer Code field
                    OnboardingQuestion(
                      questionKey: 'trainer_code',
                      questionDefault: 'Trainer Code',
                      questionTextStyle:
                          Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontSize: 16.sp,
                                color: const Color(0xFF1D2129),
                                letterSpacing: -0.24,
                              ),
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          TextField(
                            controller: trainerCodeController,
                            keyboardType: TextInputType.text,
                            onChanged: (value) {},
                            enabled: false,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly
                              // Only allows digits
                            ],
                            decoration: InputDecoration(
                              hintText: languageProvider.getMessage(
                                'enter_code',
                                'Enter code',
                              ),
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    letterSpacing: -0.24,
                                    color: AppColors.n50,
                                  ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16.w),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 8.h,
                    ),
                    CapsuleList<DateTime>(
                      label: languageProvider.getMessage(
                        'select_date_of_joining',
                        'Select Date of Joining',
                      ),
                      items: _trainingDetailsData?.availableDates ?? [],
                      titleBuilder: (date) => DateFormat('d MMM').format(date),
                      initialSelectedItem: selectedDate,
                      subtitleBuilder: (date) {
                        final today = DateTime.now();
                        if (date.day == today.day &&
                            date.month == today.month &&
                            date.year == today.year) {
                          return languageProvider.getMessage('today', 'Today');
                        } else if (date.day - today.day == 1) {
                          return languageProvider.getMessage(
                              'tomorrow', 'Tomorrow');
                        } else {
                          return DateFormat('EEEE').format(date); // weekday
                        }
                      },
                      onSelectionChanged: (selectedDate) {
                        setState(() {
                          this.selectedDate = selectedDate;
                        });
                      },
                    ),
                    SizedBox(
                      height: 16.h,
                    )
                  ],
                ),
              ),
            ),
    );
  }
}

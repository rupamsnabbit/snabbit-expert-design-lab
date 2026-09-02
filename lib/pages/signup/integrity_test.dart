import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/upload_documents.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/integrity_test/models.dart';
import 'package:snabbit_runner/services/integrity_test/services.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

import '../../widgets/gap.dart';
import '../../widgets/progress_indicator.dart';

class IntegrityTestWidget extends StatefulWidget {
  static const String routeName = "/integrity_test";

  const IntegrityTestWidget({super.key});

  @override
  State<IntegrityTestWidget> createState() => _IntegrityTestWidgetState();
}

class _IntegrityTestWidgetState extends State<IntegrityTestWidget> {
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  UserProfile? userProfile;
  List<IntegrityTest> integrityTestQuestions = [];
  bool init = true;
  bool loading = true;

  // bool loadingButton = false;
  String? error;

  Future<void> getIntegrityTestQuestions() async {
    try {
      Response? response;

      response = await RunnerIntegrityTestService.getAllQuestions();

      if (response != null && response.statusCode == 200) {
        final data = response.data;

        data.forEach((e) {
          try {
            IntegrityTest it = IntegrityTest.fromMap(e);
            if (it.answerOptions != null && it.answerOptions!.isNotEmpty) {
              integrityTestQuestions.add(IntegrityTest.fromMap(e));
            }
          } catch (e) {
            // DO NOTHING
          }
        });
      } else {
        error =
            "Something went wrong. Server responded with ${response?.statusCode}";
      }
    } catch (e, _) {
      error = "Something went wrong. Error occurred - $e";
    }
  }

  @override
  didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfile = userProfileProvider.user;
      //  not needed if server issue is fixed
      //  server issue is - Server stores multiple answers for each question and sends all the data.
      try {
        List<RunnerIntegrityTestAnswers> uniqueItems =
            userProfileProvider.user!.integrityTestAnswers!
                .fold<Map<int, RunnerIntegrityTestAnswers>>({}, (map, item) {
                  map[item.question.id] = item;
                  return map;
                })
                .values
                .toList();
        userProfileProvider.user!.integrityTestAnswers = uniqueItems;
      } catch (e) {
        // DO NOTHING
      }
      getIntegrityTestQuestions().then((_) {
        loading = false;
        userProfileProvider.notifyUserListeners();
      });
    }
  }

  AnswerOption? getIntegrityTestAnswer(int questionId) {
    try {
      return userProfile?.integrityTestAnswers
          ?.firstWhere((element) => element.question.id == questionId)
          .answer;
    } catch (e) {
      return null;
    }
  }

  void sliderOnChange(double? value, IntegrityTest question) {
    try {
      try {
        userProfile?.integrityTestAnswers!
                .firstWhere((e) => e.question.id == question.id)
                .answer =
            question.answerOptions!
                .firstWhere((e) => e.score.toDouble() == value);
      } catch (e) {
        userProfile?.integrityTestAnswers?.add(RunnerIntegrityTestAnswers(
          question: question,
          answer: question.answerOptions!
              .firstWhere((e) => e.score.toDouble() == value),
        ));
      }
    } catch (e) {
      showSnackbar(context, "Something went wrong. - $e");
    }
  }

  Widget sliderLabel(AnswerOption e, IntegrityTest question, double minScore) {
    AnswerOption? ao = getIntegrityTestAnswer(question.id);
    bool isActive =
        (ao?.score == e.score) || (ao == null && e.score == minScore);
    return Text(
      e.label ?? "",
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isActive ? AppColors.brand : Colors.transparent,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: !loading &&
                    userProfile?.integrityTestAnswers != null &&
                    userProfile!.integrityTestAnswers!.length ==
                        integrityTestQuestions.length
                ? () async {
                    await userProfileProvider.runnerRegistrationAndErrorHandler(
                      context: context,
                      onError: (errorMessage) {
                        showSnackbar(
                            context, errorMessage ?? "Something went wrong");
                      },
                    );
                  }
                : null,
            child: Text(
              languageProvider.getMessage(
                'complete_test',
                'Complete Test',
              ),
            ),
          ),
        ),
      ],
      body: loading || userProfileProvider.loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : userProfile == null
              ? const Center(
                  child: Text("User not found."),
                )
              : error != null
                  ? Center(
                      child: Text(error ?? "Something went wrong"),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ProgressIndicatorAtTop(value: 5),
                          Gap.gap32h,
                          const OnboardingPageHeader(
                            titleKey: 'integrity_test_title',
                            titleDefault: 'Integrity Test',
                            subtitleKey: 'integrity_test_subtitle',
                            subtitleDefault:
                                'What are your feelings towards these situations',
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: integrityTestQuestions.length,
                            itemBuilder: (context, index) {
                              final question = integrityTestQuestions[index];
                              if (question.answerOptions == null ||
                                  question.answerOptions!.isEmpty) {
                                return Container();
                              }
                              // double? maxScore;
                              // double? minScore;
                              question.answerOptions
                                  ?.sort((a, b) => a.option.compareTo(b.option));
                              // for (var answer in question.answerOptions!) {
                              //   if (maxScore == null ||
                              //       answer.score > maxScore) {
                              //     maxScore = answer.score;
                              //   }
                              //   if (minScore == null ||
                              //       answer.score < minScore) {
                              //     minScore = answer.score;
                              //   }
                              // }
                              // maxScore ??= 2;
                              // minScore ??= -2;
                              // totalQues++;
                              return OnboardingQuestion(
                                questionKey: question.questionLabel ?? '',
                                questionDefault: question.questionText ??
                                    question.questionLabel ??
                                    "",
                                answer: (question.answerOptions?.isNotEmpty ??
                                        false)
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              question
                                                  .answerOptions!.first.label!,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    color: AppColors.n70,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                          ...question.answerOptions!.map((e) {
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  e.option,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                        color: AppColors.n70,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                                Radio<double>(
                                                  activeColor: AppColors.brand,
                                                  value: e.score,
                                                  groupValue:
                                                      getIntegrityTestAnswer(
                                                              question.id)
                                                          ?.score,
                                                  onChanged: (val) {
                                                    sliderOnChange(
                                                        val, question);
                                                    userProfileProvider
                                                        .notifyUserListeners();
                                                  },
                                                ),
                                              ],
                                            );
                                          }),
                                          Expanded(
                                            child: Text(
                                              question
                                                  .answerOptions!.last.label!,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    color: AppColors.n70,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox(),
                              );
                            },
                          ),
                          SizedBox(height: 16.h),
                        ],
                      ),
                    ),
    );
  }
}

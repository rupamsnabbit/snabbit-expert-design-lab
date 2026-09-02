import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/hood.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/maps_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import '../../widgets/circular_checkbox.dart';
import '../../utils/common_methods.dart';

class AvailabilityDetails2 extends StatefulWidget {
  static const String routeName = "/availability_details_2";

  const AvailabilityDetails2({super.key});

  @override
  State<AvailabilityDetails2> createState() => _AvailabilityDetails2State();
}

class _AvailabilityDetails2State extends State<AvailabilityDetails2> {
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late UserProfile userProfile;
  bool init = true;

  List<Cluster>? clusters;

  @override
  void initState() {
    super.initState();
    fetchClusters();
  }

  void fetchClusters() async {
    final res = await MapsHttp.fetchClusters();

      if (res != null && res.statusCode == 200) {
        clusters =
            res.data.map((e) => Cluster.fromMap(e)).toList().cast<Cluster>();
        setState(() {});
      } else {
        clusters = [];
        setState(() {});
        if (mounted) {
          ErrorHandler.handleResponseError(
            response: res,
            context: context,
            onError: (context, responseError) {
              showSnackbar(
                context,
                "${responseError.errors?.first.message}",
              );
            },
          );
        }
      }
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;
      // userProfile.registrationStep = RunnerRegistrationStep.availability;
    }
    super.didChangeDependencies();
  }

  void onContinue() async {
    await userProfileProvider.runnerRegistrationAndErrorHandler(
      context: context,
      onError: (errorMessage) {
        showSnackbar(context, errorMessage ?? "Something went wrong");
      },
    );
  }

  void clusterSelected(Cluster cluster) {
    try {
      if ((userProfile.otherDetails?.willingClusters?.isNotEmpty ?? false) &&
          userProfile.otherDetails!.willingClusters!.contains(cluster.id)) {
        userProfile.otherDetails!.willingClusters!.remove(cluster.id);
      } else {
        if (userProfile.otherDetails?.willingClusters != null) {
          userProfile.otherDetails!.willingClusters!.add(cluster.id);
        } else {
          userProfile.otherDetails?.willingClusters = [cluster.id];
        }
      }
      userProfileProvider.notifyUserListeners();
    } catch (e) {
      showSnackbar(context, 'Something went wrong - $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: !userProfileProvider.loading && continueCondtions()
                ? onContinue
                : null,
            child: Text(
              languageProvider.getMessage(
                'continue',
                'Continue',
              ),
            ),
          ),
        ),
      ],
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: userProfileProvider.loading
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProgressIndicatorAtTop(value: 9),
                    Gap.gap32h,
                    const OnboardingPageHeader(
                      titleKey: 'job_details_title',
                      titleDefault: 'Job Details',
                      subtitleKey: 'job_details_subtitle',
                      subtitleDefault: 'Tell us your working details',
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'willing_clusters',
                      questionDefault: 'Which areas are you willing to work?',
                      answer: clusters == null
                          ? const CupertinoActivityIndicator()
                          : clusters?.isEmpty == true
                              ? Text(
                                  languageProvider.getMessage(
                                      "no_nearby_clusters",
                                      "Your location is not near to any areas we provide service to.\nTry another location?"),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.r40,
                                      ),
                                )
                              : GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 3,
                                  mainAxisSpacing: 3,
                                  childAspectRatio: 3,
                                  children: clusters!.map((cluster) {
                                    return GestureDetector(
                                      onTap: () {
                                        clusterSelected(cluster);
                                      },
                                      child: Row(
                                        children: [
                                          CircularCheckbox(
                                            squircle: true,
                                            value: userProfile.otherDetails
                                                    ?.willingClusters
                                                    ?.contains(cluster.id) ??
                                                false,
                                          ),
                                          Gap.gap8w,
                                          Text(
                                            cluster.name ?? "",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                    ),
                    Gap.gap16h,
                  ],
                ),
              ),
      ),
    );
  }

  bool continueCondtions() {
    try {
      if (userProfile.otherDetails?.willingClusters?.isNotEmpty ?? false) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}

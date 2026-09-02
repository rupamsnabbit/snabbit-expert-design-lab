import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

import '../../../providers/language_provider.dart';
import '../../../providers/user_profile.dart';
import '../../../services/server_requests/maps_http.dart';
import '../../../widgets/onboarding_question.dart';
import 'registration_review.dart';

class PersonalDetailsReview extends StatefulWidget {
  const PersonalDetailsReview({super.key});

  @override
  State<PersonalDetailsReview> createState() => _PersonalDetailsReviewState();
}

class _PersonalDetailsReviewState extends State<PersonalDetailsReview> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  UserProfile? userProfile;
  bool locationLoading = true;
  String? locationData;
  Address? currentAddress;
  Address? permanentAddress;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfile = userProfileProvider.user;
      currentAddress=userProfileProvider.getCurrentAddress();
      permanentAddress= userProfileProvider.getPermanentAddress();
      getSavedUserGeoLocation();
    }
    super.didChangeDependencies();
  }

  Future<void> getSavedUserGeoLocation() async {
    try {
      final url =
          'api/v1/geos/locations/place?place_id=${currentAddress?.placeId}';

      final response = await MapsHttp.fetchUrl(url);

      if (response != null && response.statusCode == 200) {
        final json = response.data;

        setState(() {
          locationData = json['address']['address_text'];

          locationLoading = false;
        });
      } else {
        setState(() {
          locationLoading = false;
          locationData = 'Data not found - ${response?.statusCode}';
        });
      }
    } catch (e) {
      locationLoading = false;
      locationData = 'Data not found - $e';
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingQuestion(
          questionKey: 'full_name',
          questionDefault: 'Full name (First & Last name)',
          mandatory: true,
          answer: ReviewAnswer(
            data: '${userProfile?.name}',
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionDefault: 'Gender',
          questionKey: 'gender',
          mandatory: true,
          answer: ReviewAnswer(
            data: '${userProfile?.gender?.value?.name.capitalize()}',
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: OnboardingQuestion(
                questionKey: 'height',
                questionDefault: 'Height(cm)',
                mandatory: true,
                answer: ReviewAnswer(
                  data: '${userProfile?.otherDetails?.height?.value?.toInt()}',
                ),
              ),
            ),
            Expanded(
              child: OnboardingQuestion(
                questionKey: 'weight',
                questionDefault: 'Weight(kg)',
                mandatory: true,
                answer: ReviewAnswer(
                  data: '${userProfile?.otherDetails?.weight?.value?.toInt()}',
                ),
              ),
            ),
          ],
        ),
        if (userProfile != null && userProfile?.dob?.value != null) ...[
          SizedBox(height: 16.h),
          OnboardingQuestion(
            questionKey: 'runner_dob',
            questionDefault: 'Date of Birth',
            mandatory: true,
            answer: ReviewAnswer(
              data: DateFormat('dd/MM/yyyy').format(userProfile!.dob!.value!),
            ),
          )
        ],
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionKey: 'father_name',
          questionDefault: 'Father name',
          mandatory: true,
          answer: ReviewAnswer(
            data: '${userProfile?.fatherName}',
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionKey: 'marital_status',
          questionDefault: 'Select your marital status',
          mandatory: true,
          answer: ReviewAnswer(
            data: '${userProfile?.maritalStatus?.name.capitalize()}',
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionKey: 'permanent_address',
          questionDefault: 'Permanent Address',
          mandatory: true,
          answer: ReviewAnswer(
            data: '${permanentAddress?.addressLine1}',
          ),
        ),
        SizedBox(height: 16.h),
        OnboardingQuestion(
          questionKey: 'current_address',
          questionDefault: 'Current Address',
          mandatory: true,
          answer: ReviewAnswer(
            data: '${currentAddress?.addressLine1}',
          ),
        ),
        SizedBox(height: 16.h),
        if (locationLoading == false)
          OnboardingQuestion(
            questionKey: 'location',
            questionDefault: 'Location',
            mandatory: true,
            answer: ReviewAnswer(
              data: '$locationData',
            ),
          ),
      ],
    );
  }
}

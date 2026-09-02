// ignore_for_file: use_build_context_synchronously

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:location/location.dart' as loc;
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/server_requests/maps_http.dart';
import 'package:snabbit_runner/utils/ui_helper.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'dart:async';
import 'package:snabbit_runner/pages/signup/location_change.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/progress_indicator.dart';
import 'package:snabbit_runner/widgets/text_form.dart';
import '../../providers/user_profile.dart';
import '../../utils/colors.dart';
import '../../utils/custom_themes/text_themes.dart';
import '../../utils/enums.dart';
import '../../widgets/dob_selector.dart';

class PersonalDetails extends StatefulWidget {
  static const String routeName = "/personal_details";

  const PersonalDetails({super.key});

  @override
  State<PersonalDetails> createState() => _PersonalDetailsState();
}

class _PersonalDetailsState extends State<PersonalDetails> {
  TextEditingController nameController = TextEditingController();
  TextEditingController fatherNameController = TextEditingController();
  TextEditingController permanentAddressController = TextEditingController();
  TextEditingController currentAddressController = TextEditingController();
  TextEditingController locationController = TextEditingController();

  // dynamic error;

  // dynamic _address = '';
  bool locationLoading = true;

  // bool loading = false;

  // dynamic placeId;
  final loc.Location _location = loc.Location();
  dynamic languagePref;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  UserProfile? userProfile;
  bool init = true;
  List<String>? maritalStatusKeys;
  List<MaritalStatus>? maritalStatus;

  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();

  TextEditingController heightController = TextEditingController(); //cm
  TextEditingController weightController = TextEditingController(); //kg
  Address? currentAddress;
  Address? permanentAddress;

  List<int>? bmiRange;

  Future<void> getSavedUserGeoLocation() async {
    final url =
        'api/v1/geos/locations/place?place_id=${currentAddress?.placeId}';

    final response = await MapsHttp.fetchUrl(url);

    if (response != null && response.statusCode == 200) {
      final json = response.data;

      setState(() {
        locationController.text = json['address']['address_text'];

        locationLoading = false;
      });
    } else {
      setState(() {
        locationLoading = false;
      });
      final data = response?.data;
      showSnackbar(context, "${data['detail'] ?? "Something went wrong."}");
    }
  }

  Future<void> initProcess() async {
    try {
      // await _compulsoryLocationPermission(context);
      if (currentAddress?.placeId != null) {
        getSavedUserGeoLocation();
      } else {
        locationLoading = false;
      }
    } catch (e) {
      // DO NOTHING
    }
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      userProfile = userProfileProvider.user!;
      currentAddress = userProfileProvider.getCurrentAddress();
      permanentAddress = userProfileProvider.getPermanentAddress();
      // userProfileProvider.user?.address ??= Address(id: -1);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);

      // userProfile?.registrationStep = RunnerRegistrationStep.personal;
      nameController.text = userProfile?.name ?? '';
      fatherNameController.text = userProfile?.fatherName ?? '';
      currentAddressController.text = currentAddress?.addressLine1 ?? '';
      if (permanentAddress?.addressLine1 == null ||
          permanentAddress?.addressLine1?.trim().isEmpty == true) {
        GlobalState().canEditPermanentAddress = true;
      } else {
        permanentAddressController.text = permanentAddress?.addressLine1 ?? '';
      }
      DateTime? runnerDobBackend = userProfile?.dob?.value;
      if (runnerDobBackend != null) {
        dayController.text = runnerDobBackend.day.toString().padLeft(2, '0');
        monthController.text =
            runnerDobBackend.month.toString().padLeft(2, '0');
        yearController.text = runnerDobBackend.year.toString();
      } else if (userProfile?.yob != null) {
        yearController.text = userProfile?.yob ?? '';
      } else {
        GlobalState().canEditDob = true;
      }
      if (userProfile?.otherDetails?.height?.value != null) {
        heightController.text =
            anyValueToInt(userProfile!.otherDetails!.height!.value).toString();
      }
      if (userProfile?.otherDetails?.weight?.value != null) {
        weightController.text =
            anyValueToInt(userProfile!.otherDetails!.weight!.value).toString();
      }

      maritalStatusKeys = GlobalState().appConfig?.maritalStatus;
      if (maritalStatusKeys != null) {
        maritalStatus = maritalStatusKeys
            ?.map(
              (status) => getMaritalStatusFromString(status),
            )
            .whereType<MaritalStatus>()
            .toList();
      }

      bmiRange = List<int>.from(
          GlobalState().appConfig?.getCriticalField('bmi_range') ?? []);

      initProcess().then((_) {
        setState(() {});
      });
    }
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
  }

  // Future<void> _getLocation() async {
  //   bool serviceEnabled;
  //   loc.PermissionStatus permissionGranted;
  //   loc.LocationData locationData;

  //   // Check if location services are enabled
  //   serviceEnabled = await _location.serviceEnabled();
  //   if (!serviceEnabled) {
  //     serviceEnabled = await _location.requestService();
  //     if (!serviceEnabled) {
  //       return;
  //     }
  //   }

  //   // Check for location permissions
  //   permissionGranted = await _location.hasPermission();
  //   if (permissionGranted == loc.PermissionStatus.denied) {
  //     permissionGranted = await _location.requestPermission();
  //     if (permissionGranted != loc.PermissionStatus.granted) {
  //       return;
  //     }
  //   }

  //   // Get the current location
  //   locationData = await _location.getLocation();
  //   _getAddressFromLatLng(locationData.latitude!, locationData.longitude!);
  //   // getPlaceId(locationData.latitude!, locationData.longitude!);
  //   debugPrint(locationData.latitude!.toString());
  //   debugPrint(locationData.longitude!.toString());
  // }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final response = await MapsHttp.fetchUrl(
          'api/v1/geos/locations/details?lat=$lat&lng=$lng&skip_serviceability_check=true');
      if (response != null && response.statusCode == 200) {
        final data = response.data;

        currentAddress?.placeId = data['place_id'];
        locationController.text = data['address']['address_text'];
        locationLoading = false;
        userProfileProvider.notifyUserListeners();
      } else {
        // print('Request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // print(e);
    }
  }

  // Future<void> _compulsoryLocationPermission(
  //   BuildContext context,
  // ) async {
  //   if (await Permission.locationAlways.isGranted == false) {
  //     try {
  //       showLocationPermissionConfirmation();
  //     } catch (e) {
  //       // DO NOTHING
  //     }
  //   }
  // }

  // Future<void> _getAddressFromLatLng(double latitude, double longitude) async {
  //   try {
  //     List<Placemark> placemarks =
  //         await placemarkFromCoordinates(latitude, longitude);
  //     Placemark place = placemarks[0];

  //     setState(() {
  //       _address =
  //           "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
  //       locationController.text = _address;
  //       locationLoading = false;
  //     });
  //   } catch (e) {
  //     debugPrint(e.toString());
  //     setState(() {
  //       _address = "Failed to get address";
  //     });
  //   }
  // }

  void _selectDate(BuildContext context) async {
    try {
      final dobYear = userProfile?.yob;
      DateTime? picked;
      if (dobYear == null) {
        final currentDate = DateTime.now();
        final initialDate =
            currentDate.subtract(const Duration(days: 365 * 18));
        picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(1900),
          lastDate: initialDate,
        );
      } else {
        final yob = int.tryParse(dobYear);
        final firstDate = DateTime(yob ?? 1900);
        picked = await showDatePicker(
          context: context,
          initialDate: firstDate,
          firstDate: firstDate,
          lastDate: yob == null ? DateTime.now() : DateTime(yob, 12, 31),
        );
      }
      if (picked != null) {
        setState(() {
          dayController.text = picked!.day.toString().padLeft(2, '0');
          monthController.text = picked.month.toString().padLeft(2, '0');
          yearController.text = picked.year.toString();
        });
        userProfileProvider.user?.dob?.value = picked;
        userProfileProvider.notifyUserListeners();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: !userProfileProvider.loading && continueConditions()
                ? () async {
                    await userProfileProvider.runnerRegistrationAndErrorHandler(
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
      ],
      body: userProfileProvider.loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProgressIndicatorAtTop(value: 1),
                    Gap.gap32h,
                    const OnboardingPageHeader(
                      titleKey: "personal_details_title",
                      titleDefault: "Personal Details",
                      subtitleKey: 'personal_details_subtitle',
                      subtitleDefault:
                          "Please ensure all the details are accurate",
                    ),
                    Gap.gap32h,
                    OnboardingQuestion(
                      questionKey: 'full_name',
                      questionDefault: 'Full name (First & Last name)',
                      mandatory: true,
                      answer: TextFormSnabbit(
                        controller: nameController,
                        hintText: languageProvider.getMessage(
                          'full_name_hint',
                          'Enter your full name',
                        ),
                        onChanged: (v) {
                          userProfile?.name = v.isNotEmpty ? v : null;
                          userProfileProvider.notifyUserListeners();
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z ]')),
                        ],
                        enabled: false,
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      questionKey: 'gender',
                      questionDefault: 'Gender',
                      mandatory: true,
                      criticalError:
                          userProfile?.gender?.isValueAcceptable() == true
                              ? null
                              : languageProvider.getMessage(
                                  'pls_review_answer_carefully',
                                  "Please review this answer carefully",
                                ),
                      answer: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              userProfile?.gender?.value = Gender.MALE;
                              userProfileProvider.notifyUserListeners();
                            },
                            child: Row(
                              children: [
                                CircularCheckbox(
                                    value: userProfile?.gender?.value ==
                                            Gender.MALE
                                        ? true
                                        : false),
                                Gap.gap8w,
                                Text(
                                  languageProvider.getMessage(
                                    'male',
                                    'Male',
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Padding(
                                  padding: EdgeInsets.only(left: 8.w),
                                  child: SvgPicture.asset(
                                      AssetConstants.genderMale),
                                )
                              ],
                            ),
                          ),
                          Gap.gap32w,
                          GestureDetector(
                            onTap: () {
                              userProfile?.gender?.value = Gender.FEMALE;
                              userProfileProvider.notifyUserListeners();
                            },
                            child: Row(
                              children: [
                                CircularCheckbox(
                                    value: userProfile?.gender?.value ==
                                            Gender.FEMALE
                                        ? true
                                        : false),
                                Gap.gap8w,
                                Text(
                                  languageProvider.getMessage(
                                    'female',
                                    'Female',
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Padding(
                                  padding: EdgeInsets.only(left: 8.w),
                                  child: SvgPicture.asset(
                                      AssetConstants.genderFemale),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      questionKey: 'height',
                      questionDefault: 'Height (cm)',
                      mandatory: true,
                      // questionSubtitle: "Value should be between 105 & 190",
                      criticalError: getBMICriticalError(),
                      error: userProfile?.otherDetails?.height
                                  ?.isValueAcceptable() !=
                              true
                          ? "${languageProvider.getMessage(
                              'height_should_be_between',
                              "Height should be between",
                            )} ${userProfile?.otherDetails?.height?.acceptedValues?.first} & ${userProfile?.otherDetails?.height?.acceptedValues?.last}"
                          : null,
                      answer: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9]')),
                                LengthLimitingTextInputFormatter(3),
                              ],
                              controller: heightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Ex. 170',
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
                          Padding(
                            padding: EdgeInsets.only(left: 12.w),
                            child: SvgPicture.asset(AssetConstants.heightScale),
                          )
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      questionKey: 'weight',
                      questionDefault: 'Weight (kgs)',
                      mandatory: true,
                      criticalError: getBMICriticalError(),
                      error: _weightHasError
                          ? "${languageProvider.getMessage(
                              'weight_should_be_between',
                              "Weight should be between",
                            )} ${userProfile?.otherDetails?.weight?.acceptedValues?.first} & ${userProfile?.otherDetails?.weight?.acceptedValues?.last}"
                          : null,
                      answer: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9]')),
                                LengthLimitingTextInputFormatter(3),
                              ],
                              controller: weightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Ex. 60',
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
                          Padding(
                            padding: EdgeInsets.only(left: 12.w),
                            child: SvgPicture.asset(AssetConstants.weightScale),
                          )
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    // Date of birth field
                    OnboardingQuestion(
                      mandatory: true,
                      questionKey: 'runner_dob',
                      questionDefault: 'Date of Birth',
                      criticalError: isDobValid()
                          ? null
                          : languageProvider.getMessage(
                              'pls_review_answer_carefully',
                              "Please review this answer carefully",
                            ),
                      answer: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap.gap8h,
                          DobSelector(
                            onTap: () {
                              _selectDate(context);
                            },
                            dobDay: dayController,
                            dobMonth: monthController,
                            dobYear: yearController,
                            enabled: GlobalState().canEditDob ||
                                !(userProfile?.dob?.value != null),
                          ),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      questionKey: 'father_name',
                      questionDefault: 'Father name',
                      mandatory: true,
                      answer: TextFormSnabbit(
                        controller: fatherNameController,
                        hintText: languageProvider.getMessage(
                          'full_name_hint',
                          'Enter your father\'s name',
                        ),
                        onChanged: (v) {
                          userProfile?.fatherName = v.isNotEmpty ? v : null;
                          userProfileProvider.notifyUserListeners();
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z ]')),
                        ],
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      questionKey: 'marital_status',
                      questionDefault: 'Select your marital status',
                      mandatory: true,
                      answer: maritalStatus == null
                          ? UiHelper.showLoadFailError(context)
                          : GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 4,
                              children: List.generate(
                                maritalStatus?.length ?? 0,
                                (index) {
                                  return GestureDetector(
                                    onTap: () {
                                      userProfile?.maritalStatus =
                                          maritalStatus?[index];
                                      // getMaritalStatusFromString(maritalStatus?[index]);
                                      // MaritalStatus.values.elementAt(index);
                                      userProfileProvider.notifyUserListeners();
                                    },
                                    child: Row(
                                      children: [
                                        CircularCheckbox(
                                            value: userProfile?.maritalStatus ==
                                                maritalStatus?[index]
                                            // MaritalStatus.values.elementAt(index),
                                            ),
                                        Gap.gap3w,
                                        Text(
                                          // toBeginningOfSentenceCase(MaritalStatus
                                          //     .values
                                          //     .elementAt(index)
                                          //     .name),
                                          languageProvider.getMessage(
                                              maritalStatusKeys![index],
                                              maritalStatusKeys![index]),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      questionKey: 'permanent_address',
                      questionDefault: 'Permanent Address',
                      mandatory: true,
                      answer: TextFormSnabbit(
                        controller: permanentAddressController,
                        hintText: 'Enter your address',
                        onChanged: (v) {
                          permanentAddress?.addressLine1 = v;
                          userProfileProvider.notifyUserListeners();
                        },
                        enabled: GlobalState().canEditPermanentAddress ||
                            !(permanentAddress?.addressLine1 != null &&
                                permanentAddress?.addressLine1
                                        ?.trim()
                                        .isNotEmpty ==
                                    true),
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      questionKey: 'current_address',
                      questionDefault: 'Current Address',
                      mandatory: true,
                      answer: TextFormSnabbit(
                        controller: currentAddressController,
                        hintText: 'Enter your address',
                        onChanged: (v) {
                          currentAddress?.addressLine1 = v;
                          userProfileProvider.notifyUserListeners();
                        },
                      ),
                    ),
                    Gap.gap16h,
                    OnboardingQuestion(
                      questionKey: 'location',
                      questionDefault: 'Location',
                      mandatory: true,
                      answer: Column(
                        children: [
                          locationLoading
                              ? Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8.r),
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.transparent,
                                    color: AppColors.brand,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                )
                              : Container(),
                          TextFormField(
                            readOnly: true,
                            controller: locationController,
                            onChanged: (v) {
                              setState(() {
                                locationController.text = v;
                              });
                            },
                            decoration: InputDecoration(
                              suffix: locationLoading
                                  ? Padding(
                                      padding: EdgeInsets.only(left: 8.r),
                                      child: const CupertinoActivityIndicator(),
                                    )
                                  : GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const LocationChange(),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.only(left: 8.w),
                                        child: Text(
                                          languageProvider.getMessage(
                                            'change',
                                            'Change',
                                          ),
                                          style:
                                              TextStyle(color: AppColors.brand),
                                        ),
                                      ),
                                    ),
                              hintText: languageProvider.getMessage(
                                'location_hint',
                                'Click here to update your location',
                              ),
                              hintStyle: AppTextTheme.hintStyle,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.gap8h,
                    userProfileProvider.error != null
                        ? Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: Text(
                                userProfileProvider.error ??
                                    "Something went wrong",
                                style: AppTextTheme.errStyle),
                          )
                        : Container(),
                  ],
                ),
              ),
            ),
    );
  }

  bool continueConditions() {
    if ((userProfileProvider.user?.name?.trim().isNotEmpty == true) &&
        (currentAddress?.addressLine1?.trim().isNotEmpty ?? false) &&
        (permanentAddress?.addressLine1?.trim().isNotEmpty ?? false) &&
        (userProfileProvider.user?.fatherName?.trim().isNotEmpty ?? false) &&
        locationController.text.trim().isNotEmpty &&
        userProfileProvider.user?.dob?.value != null &&
        userProfile?.otherDetails?.height?.value != null &&
        userProfile?.otherDetails?.weight?.value != null &&
        userProfile?.gender?.value != null &&
        userProfile?.maritalStatus != null &&
        !_weightHasError &&
        userProfile?.otherDetails?.height?.isValueAcceptable() == true) {
      return true;
    } else {
      return false;
    }
  }

  bool isDobValid() {
    final today = DateTime.now();
    final dob = userProfileProvider.user?.dob;
    if (dob?.value == null ||
        dob?.acceptedValues == null ||
        dob?.acceptedValues?.isEmpty == true) {
      return true;
    }
    final yearsOld =
        ((dob!.value!.difference(today)).abs().inDays / ~365).abs();
    return yearsOld >= dob.acceptedValues?.first &&
        yearsOld <= dob.acceptedValues?.last;
  }

  String? getBMICriticalError() {
    final weight = userProfileProvider.user?.otherDetails?.weight?.value;
    final height = userProfileProvider.user?.otherDetails?.height?.value;
    if (weight == null ||
        height == null ||
        bmiRange == null ||
        bmiRange?.isEmpty == true) {
      return null;
    }
    // Convert height from centimeters to meters
    double heightMeters = height / 100;

    // Calculate the minimum weight
    final minWeightKg = bmiRange!.first * pow(heightMeters, 2);

    // Calculate the maximum weight
    final maxWeightKg = bmiRange!.last * pow(heightMeters, 2);

    return weight >= minWeightKg && weight <= maxWeightKg
        ? null
        : languageProvider.getMessage(
            'pls_review_answer_carefully',
            "Please review this answer carefully",
          );
  }

  bool get _weightHasError =>
      userProfile?.otherDetails?.weight?.isValueAcceptable() != true;
}

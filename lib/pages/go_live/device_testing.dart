import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/go_live/device_status.dart';
import 'package:snabbit_runner/pages/go_live/uniform_confirmation.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/go_live_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/go_live/audio_tester.dart';
import 'package:snabbit_runner/widgets/go_live/device_feature_test_tile.dart';
import 'package:snabbit_runner/widgets/go_live/device_test_failed_warning.dart';
import 'package:snabbit_runner/widgets/go_live/location_tester.dart';
import 'package:snabbit_runner/widgets/go_live/camera_tester.dart';
import 'package:snabbit_runner/widgets/go_live/vibration_tester.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

class DeviceTesting extends StatefulWidget {
  static const String routeName = '/device-testing';

  const DeviceTesting({super.key});

  @override
  State<DeviceTesting> createState() => _DeviceTestingState();
}

class _DeviceTestingState extends State<DeviceTesting> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  final TextEditingController childNameController = TextEditingController();
  bool init = true;
  List<bool?> _results =
      List.filled(4, null); // For camera, location, speaker, vibration
  int _attempts = 0;
  int _currentTestIndex = -1;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      Future(() {
        setState(() {
          _currentTestIndex = findNextNonTrueIndex();
        });
      });
    }
    super.didChangeDependencies();
  }

  void _continue() {
    reportPhoneIntegrity();
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
                onPressed: _allTestsPassed ? _continue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.n0,
                ),
                child: Text(
                  languageProvider.getMessage(
                    "proceed",
                    "Proceed",
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 23.h,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 16.h,
          ),
          width: 1.sw,
          decoration: BoxDecoration(
            color: AppColors.n0,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OnboardingPageHeader(
                titleKey: "device_testing_title",
                titleDefault: "Device testing",
                subtitleKey: '',
                subtitleDefault: '',
                titleStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      // CSS: font-weight: 600; (Semi Bold)
                      fontStyle: FontStyle.normal,
                      // CSS: font-style: Semi Bold; (Flutter uses FontWeight for "Semi Bold")
                      fontSize: 16.sp,
                      // CSS: font-size: 16px;
                      height: 18 / 16,
                      // CSS: line-height: 18px; (calculated as line-height / font-size)
                      letterSpacing: 0.0, // CSS: letter-spacing: 0px;
                    ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DeviceFeatureTestTile(
                        leadingIcon: AssetConstants.famiconsCameraOutlined,
                        titleText: 'Camera',
                        titleKey: 'camera',
                        isExpanded: shouldExpandTest(0),
                        reset: shouldResetTest(0),
                        expandedContentBuilder: (onSuccess, onFailure) =>
                            CameraTester(
                          onSuccess: () {
                            onSuccess();
                            defaultCallback(true);
                          },
                          onFailure: () {
                            onFailure();
                            defaultCallback(false);
                          },
                        ),
                      ),
                      SizedBox(height: 16.h),
                      DeviceFeatureTestTile(
                        leadingIcon: AssetConstants.locationPinOutlined,
                        titleText: 'Location',
                        titleKey: 'location_access',
                        isExpanded: shouldExpandTest(1),
                        reset: shouldResetTest(1),
                        expandedContentBuilder: (onSuccess, onFailure) =>
                            LocationTester(
                          onSuccess: () {
                            onSuccess();
                            defaultCallback(true);
                          },
                          onFailure: () {
                            onFailure();
                            defaultCallback(false);
                          },
                        ),
                      ),
                      SizedBox(height: 16.h),
                      DeviceFeatureTestTile(
                        leadingIcon: AssetConstants.fluentSpeakerOutlined,
                        titleText: 'Speaker',
                        titleKey: 'speaker_access',
                        isExpanded: shouldExpandTest(2),
                        reset: shouldResetTest(2),
                        expandedContentBuilder: (onSuccess, onFailure) =>
                            AudioTester(
                          onSuccess: () {
                            onSuccess();
                            defaultCallback(true);
                          },
                          onFailure: () {
                            onFailure();
                            defaultCallback(false);
                          },
                        ),
                      ),
                      SizedBox(height: 16.h),
                      DeviceFeatureTestTile(
                        leadingIcon: AssetConstants.lightVibrationOutlined,
                        titleText: 'Vibration',
                        titleKey: 'vibration_access',
                        isExpanded: shouldExpandTest(3),
                        reset: shouldResetTest(3),
                        expandedContentBuilder: (onSuccess, onFailure) =>
                            VibrationTester(
                          onSuccess: () {
                            onSuccess();
                            defaultCallback(true);
                          },
                          onFailure: () {
                            onFailure();
                            defaultCallback(false);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 16.h,
              ),
              if (_anyTestFailed && _allTestsTested)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        languageProvider.getMessage(
                            'device_testing_failed_tests_error',
                            "You need to pass all tests to go forward."),
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 14.sp,
                          color: AppColors.r40,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                        height: 21.h,
                      ),
                      OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brand,
                            side: const BorderSide(color: AppColors.brand),
                          ),
                          onPressed: () {
                            if (_attempts < 1) {
                              setState(() {
                                for (int i = 0; i < _results.length; i++) {
                                  if (_results[i] == false) {
                                    _results[i] =
                                        null; // Reset only failed tests
                                  }
                                }
                                _currentTestIndex =
                                    findNextNonTrueIndex(); // Reset to first test
                                _attempts++;
                              });
                            } else {
                              reportPhoneIntegrity(true);
                              showDeviceTestFailedWarning(context);
                            }
                          },
                          child: Text(
                            languageProvider.getMessage(
                                'device_testing_failed_tests_retry',
                                "Retry failed tests"),
                          )),
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  bool get _allTestsPassed {
    return _results.every((result) => result == true);
  }

  bool get _allTestsTested {
    return !_results.any((result) => result == null);
  }

  bool get _anyTestFailed {
    return _results.any((result) => result == false);
  }

  /// Finds the next index in the list, starting from a given index,
  /// where the boolean value is not 'true' (i.e., it's false or null).
  /// It wraps around the list if it reaches the end.
  ///
  /// Returns the index of the next non-true element, or -1 if none is found.
  int findNextNonTrueIndex() {
    if (_results.isEmpty) {
      return -1;
    }

    // Start searching from the element *after* the startIndex
    // and wrap around if necessary.
    int searchIndex = (_currentTestIndex + 1) % _results.length;
    int count = 0; // To prevent infinite loops if all are true

    while (count < _results.length) {
      if (_results[searchIndex] != true) {
        return searchIndex; // Found a non-true element
      }
      searchIndex =
          (searchIndex + 1) % _results.length; // Move to the next index
      count++;
    }

    return -1; // No non-true element found after checking the entire list
  }

  bool shouldExpandTest(int index) {
    return _currentTestIndex == index && _results[index] == null;
  }

  bool shouldResetTest(int index) {
    return _results[index] == null && _attempts > 0 && shouldExpandTest(index);
  }

  void defaultCallback(bool passed) {
    Future.delayed(Duration(milliseconds: 1000), () {
      setState(() {
        _results[_currentTestIndex] = passed;
        if (!_allTestsTested) {
          _currentTestIndex = findNextNonTrueIndex();
        }
      });
    });
  }

  void reportPhoneIntegrity([skipSuccess=false]) async {
    try {
      final deviceId = await getDeviceId();
      final response = await GoLiveHttp.reportPhoneIntegrityStatus(
          data: DeviceStatusData(
        deviceId: deviceId,
        statusCheck: StatusCheck(
          camera: _results[0],
          location: _results[1],
          speaker: _results[2],
          vibration: _results[3],
        ),
      ));
      if(response!=null){
        if (response.statusCode == 200 && !skipSuccess) {
          Navigator.pushReplacementNamed(
              context, UniformConfirmationPage.routeName);
        } else {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              showSnackbar(
                  context,
                  responseError.errors?.first.message ??
                      "Error reporting phone integrity. Please try again later.");
            },
          );
        }
      } else {
        showSnackbar(
            context, "Error reporting phone integrity. Please try again later.");
      }
    } catch (_) {
      showSnackbar(
          context, "Error reporting phone integrity. Please try again later.");
    }
  }
}

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../utils/colors.dart';
import '../../utils/custom_themes/text_themes.dart';

class LocationChangeV2 extends StatefulWidget {
  static const String routeName = "/location_change_v2";

  const LocationChangeV2({super.key});

  @override
  State<LocationChangeV2> createState() => _LocationChangeV2State();
}

class _LocationChangeV2State extends State<LocationChangeV2> {
  static const _addressLine1Key = 'address line 1';
  static const _addressLine2Key = 'address line 2';
  static const _cityKey = 'city';
  static const _stateKey = 'state';
  static const _countryKey = 'country';
  static const _pincodeKey = 'pincode';
  static const _latitudeKey = 'latitude';
  static const _longitudeKey = 'longitude';
  static const _geoAddressKey = 'geo address';

  bool init = true;
  bool loading = true;
  bool buttonLoading = false;

  GoogleMapController? _mapController;
  LatLng? _pendingCameraTarget;
  bool _isProgrammaticCameraMove = false;

  Location locationController = Location();
  LatLng? currentPosition;

  double zoomValue = 19;
  String? selectedPlaceId;
  String? placeId;

  // Address components for the 10 questions
  String? addressLine1;
  String? addressLine2;
  String? city;
  String? state;
  String? country;
  String? pincode;
  double? latitude;
  double? longitude;
  String? geoAddress;
  bool isServiceable = false;
  bool _shouldReverseGeocodeOnIdle = false;
  bool _hasPrefilledData = false;

  // Todo: set the value of this
  String? _mapMarkerImageUrl;

  // Todo: set the value of this
  String? _locateMeImageUrl;

  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;

  late final TextEditingController _pincodeController;

  OnboardingQuestionResponse? get onboardingQuestionResponse =>
      onboardingStepsProvider.onboardingQuestionResponse;

  List<OnboardingQuestionData>? get questions =>
      onboardingQuestionResponse?.questions;

  int? get sessionId => onboardingQuestionResponse?.sessionId;

  int get _currentIndex =>
      onboardingQuestionResponse?.currentQuestionNumber ?? 0;

  int get _totalSteps => onboardingQuestionResponse?.totalQuestions ?? 0;

  double get _progressValue =>
      _totalSteps == 0 ? 0 : _currentIndex / _totalSteps;

  @override
  void initState() {
    _pincodeController = TextEditingController();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      placeId = userProfileProvider.getCurrentAddress()?.placeId;
      Future.microtask(() async {
        await _prefillLocationFromPreviousResponse();
        await _initializeLocation();

        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> _prefillLocationFromPreviousResponse() async {
    if (questions == null || questions!.isEmpty) return;

    String? placeIdFromResponse;

    for (final question in questions!) {
      final previousResponse = question.previousResponse;
      final rawAnswer = previousResponse?.first.freeTextAnswer?.trim();
      if (rawAnswer == null || rawAnswer.isEmpty) continue;

      final key = _getQuestionKey(question);

      if (key == _addressLine1Key) {
        addressLine1 = rawAnswer;
      } else if (key == _addressLine2Key) {
        addressLine2 = rawAnswer;
      } else if (key == _cityKey) {
        city = rawAnswer;
      } else if (key == _stateKey) {
        state = rawAnswer;
      } else if (key == _countryKey) {
        country = rawAnswer;
      } else if (key == _pincodeKey) {
        pincode = rawAnswer;
      } else if (key == _latitudeKey) {
        latitude = double.tryParse(rawAnswer);
      } else if (key == _longitudeKey) {
        longitude = double.tryParse(rawAnswer);
      } else if (key == _geoAddressKey) {
        geoAddress = rawAnswer;
      } else if (key.contains('place id')) {
        placeIdFromResponse = rawAnswer;
      }
    }

    if (placeIdFromResponse != null && placeIdFromResponse.isNotEmpty) {
      placeId = placeIdFromResponse;
      selectedPlaceId = placeIdFromResponse;
    }

    if (latitude != null && longitude != null) {
      final restoredPosition = LatLng(latitude!, longitude!);
      currentPosition = restoredPosition;
      _pendingCameraTarget = restoredPosition;
      _isProgrammaticCameraMove = true;
      _hasPrefilledData = true;
      _shouldReverseGeocodeOnIdle = false;
    }
  }

  Future<void> _initializeLocation() async {
    if (_hasPrefilledData && currentPosition != null) {
      // We have prefilled data, validate serviceability
      await _checkServiceability(currentPosition!);
      // If address fields are empty, fetch them
      if (addressLine1 == null || addressLine1!.isEmpty) {
        await _getAddressFromLatLng(currentPosition!);
      }
      return;
    }

    // No prefilled data, get current location
    if (currentPosition == null) {
      await getLocationUpdates();
    }

    if (currentPosition != null) {
      await _getAddressFromLatLng(currentPosition!);
      await _checkServiceability(currentPosition!);
    }
  }

  Future<void> _checkServiceability(LatLng position) async {
    try {
      const int fallbackClusterRadius = 50;
      // Extract cluster_radius from UI config
      final clusterRadius = anyValueToInt(onboardingQuestionResponse
              ?.onboardingQuestionGroup
              ?.uiConfig
              ?.rawJson?['cluster_radius']) ??
          fallbackClusterRadius;

      // Call new API for serviceability check
      final clustersUrl = GlobalState().serverPath(
          'api/v1/geos/clusters_within_radius?lat=${position.latitude}&lng=${position.longitude}&radius_km=$clusterRadius');
      final clustersResponse =
          await HttpService().get(clustersUrl, headers: {});
      if (clustersResponse.statusCode == 200) {
        final clustersData = clustersResponse.data;

        // Check if response is a list and set serviceability based on list length
        if (clustersData is List) {
          isServiceable = clustersData.isNotEmpty;
        } else {
          // Fallback to false if response is not a list
          isServiceable = false;
        }
      }

      final detailsUrl = GlobalState().serverPath(
          'api/v1/geos/locations/details?lat=${position.latitude}&lng=${position.longitude}&skip_serviceability_check=true');
      final detailsResponse = await HttpService().get(detailsUrl, headers: {});
      if (detailsResponse.statusCode == 200) {
        final detailsData =
            Map<String, dynamic>.from(detailsResponse.data as Map);

        // Update placeId for the current position
        if (detailsData['place_id'] != null) {
          placeId = detailsData['place_id'];
        }
      }

      userProfileProvider.notifyUserListeners();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      isServiceable = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _getQuestionKey(OnboardingQuestionData question) {
    return _normalizeQuestionKey(question.question ?? '');
  }

  String _normalizeQuestionKey(String key) {
    return key.toLowerCase().trim().replaceAll(RegExp(r'[_\s]+'), ' ');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_pendingCameraTarget != null) {
      _isProgrammaticCameraMove = true;
      controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _pendingCameraTarget!, zoom: zoomValue),
        ),
      );
      _pendingCameraTarget = null;
    }
  }

  Future<void> getLocationUpdates() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await locationController.serviceEnabled();
    if (serviceEnabled) {
      serviceEnabled = await locationController.requestService();
    } else {
      return;
    }
    permissionGranted = await locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted &&
          permissionGranted != PermissionStatus.grantedLimited) {
        return;
      }
    }
    LocationData currentLocation = await locationController.getLocation();
    if (currentLocation.latitude != null && currentLocation.longitude != null) {
      currentPosition =
          LatLng(currentLocation.latitude!, currentLocation.longitude!);
    }
  }

  Future<void> locateMe() async {
    LocationData currentLocation = await locationController.getLocation();
    if (currentLocation.latitude != null && currentLocation.longitude != null) {
      try {
        final newPosition =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
        _isProgrammaticCameraMove = true;
        selectedPlaceId =
            null; // Clear selected place when using current location

        if (_mapController == null) {
          _pendingCameraTarget = newPosition;
        } else {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: newPosition, zoom: zoomValue),
            ),
          );
        }

        latitude = newPosition.latitude;
        longitude = newPosition.longitude;
        currentPosition = newPosition;

        await _getAddressFromLatLng(newPosition);
        await _checkServiceability(newPosition);

        setState(() {});
      } catch (e) {
        debugPrint(
            "error - animating map camera in location change ${e.toString()}");
      }
    }
  }

  Future<void> locateSelectedPlace(double lat, double lng) async {
    try {
      final target = LatLng(lat, lng);
      latitude = lat;
      longitude = lng;
      currentPosition = target;
      _isProgrammaticCameraMove = true;
      if (_mapController == null) {
        _pendingCameraTarget = target;
        return;
      }
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoomValue),
        ),
      );
    } catch (e) {
      // DO NOTHING
    }
    setState(() {});
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (selectedPlaceId == null) {
      try {
        final url = GlobalState().serverPath(
            'api/v1/geos/locations/details?lat=${position.latitude}&lng=${position.longitude}&skip_serviceability_check=true');
        final response = await HttpService().get(url, headers: {});
        if (response.statusCode == 200) {
          final data = Map<String, dynamic>.from(response.data as Map);

          if (data['address'] != null) {
            final addressDataRaw = data['address'];
            final addressData = addressDataRaw is Map<String, dynamic>
                ? Map<String, dynamic>.from(addressDataRaw)
                : addressDataRaw;

            final nameValue = (addressData['name'] as String?)?.trim();
            final addressTextValue =
                (addressData['address_text'] as String?)?.trim();

            geoAddress = addressTextValue;
            city = addressData['city'];
            state = addressData['state'];
            country = addressData['country'];
            pincode = addressData['pin_code'] ?? addressData['pincode'];

            final computedAddressLine1 =
                (nameValue?.isNotEmpty == true ? nameValue : addressTextValue);
            addressLine1 = computedAddressLine1 ?? addressLine1;

            if (addressTextValue != null &&
                addressLine1 != null &&
                addressTextValue.toLowerCase() != addressLine1!.toLowerCase()) {
              addressLine2 = addressTextValue;
            } else {
              addressLine2 = null;
            }
          }

          if (data['place_id'] != null) {
            placeId = data['place_id'];
          }

          latitude = position.latitude;
          longitude = position.longitude;

          userProfileProvider.notifyUserListeners();
          _shouldReverseGeocodeOnIdle = false;

          setState(() {});
        } else {
          debugPrint('Request failed with status: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Request failed with status');
        if (mounted) {
          showSnackbar(context, "Error occurred.");
        }
      }
    }
  }

  Future<void> fetchPlaceDetails(String placeId) async {
    selectedPlaceId = placeId;
    final String url = GlobalState()
        .serverPath('api/v1/geos/locations/place?place_id=$placeId');
    try {
      final response = await HttpService().get(url, headers: {});

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(response.data as Map);

        if (data['address'] != null) {
          final addressDataRaw = data['address'];
          final addressData = addressDataRaw is Map<String, dynamic>
              ? Map<String, dynamic>.from(addressDataRaw)
              : addressDataRaw;

          final nameValue = (addressData['name'] as String?)?.trim();
          final addressTextValue =
              (addressData['address_text'] as String?)?.trim();

          geoAddress = addressTextValue;
          city = addressData['city'];
          state = addressData['state'];
          country = addressData['country'];
          pincode = addressData['pin_code'] ?? addressData['pincode'];
          if(pincode==null || pincode?.isEmpty== true){
            _pincodeController.clear();
          }

          final computedAddressLine1 =
              (nameValue?.isNotEmpty == true ? nameValue : addressTextValue);
          addressLine1 = computedAddressLine1 ?? addressLine1;

          if (addressTextValue != null &&
              addressLine1 != null &&
              addressTextValue.toLowerCase() != addressLine1!.toLowerCase()) {
            addressLine2 = addressTextValue;
          } else {
            addressLine2 = null;
          }
        }

        if (data['location'] != null) {
          final lat = data['location']['lat'];
          final lng = data['location']['lng'];
          if (lat != null && lng != null) {
            latitude = lat is double ? lat : double.tryParse(lat.toString());
            longitude = lng is double ? lng : double.tryParse(lng.toString());
            if (latitude != null && longitude != null) {
              await locateSelectedPlace(latitude!, longitude!);
            }
          }
        }

        this.placeId = data['place_id'] ?? placeId;

        userProfileProvider.notifyUserListeners();

        // Check serviceability after setting the place
        if (currentPosition != null) {
          await _checkServiceability(currentPosition!);
        }

        setState(() {});
      } else {
        debugPrint('Failed to fetch place details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching place details: $e');
    }
  }

  String? _getAnswerForQuestion(OnboardingQuestionData question) {
    final questionKey = _normalizeQuestionKey(question.question ?? '');

    // Map question keys to their corresponding values
    // All values are sent as free_text_answer
    // Values come from previousResponse (prefilled) or current state
    if (questionKey == _addressLine1Key) {
      final value = addressLine1 ?? '';
      return value.isNotEmpty ? value : null;
    } else if (questionKey == _addressLine2Key) {
      final value = addressLine2 ?? '';
      return value.isNotEmpty ? value : null;
    } else if (questionKey == _cityKey) {
      return city;
    } else if (questionKey == _stateKey) {
      return state;
    } else if (questionKey == _countryKey) {
      return country;
    } else if (questionKey == _pincodeKey) {
      return pincode;
    } else if (questionKey == _latitudeKey) {
      return latitude?.toString();
    } else if (questionKey == _longitudeKey) {
      return longitude?.toString();
    } else if (questionKey == _geoAddressKey) {
      return geoAddress ?? addressLine2 ?? addressLine1;
    } else if (questionKey.contains('place id')) {
      return placeId;
    }

    return null;
  }

  Future<void> _submitLocationAnswer() async {
    if (placeId == null || currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getMessage(
                'please_select_location',
                'Please select a location',
              ),
            ),
          ),
        );
      }
      return;
    }

    if (questions == null || questions!.isEmpty || sessionId == null) {
      return;
    }

    if (latitude == null || longitude == null) {
      latitude = currentPosition!.latitude;
      longitude = currentPosition!.longitude;
    }

    // Build payload for all 10 questions in this group
    // All answers are sent as free_text_answer
    final payload = {
      "session_id": sessionId,
      "responses": questions!.map((question) {
        Map<String, dynamic> response = {
          "question_id": question.id,
          "question_type": questionTypeToApiValue(question.questionType),
        };

        // Get the answer for this specific question
        // All values come from previousResponse.freeTextAnswer or current state
        String? answer = _getAnswerForQuestion(question);
        response["free_text_answer"] = answer ?? "";

        return response;
      }).toList(),
    };

    onboardingStepsProvider.submitAnswerAndProceed(
      context: context,
      data: payload,
      onSuccess: () {
        // Navigation is handled by the provider
      },
      onError: (CustomError error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(error.message ?? error.title ?? 'An error occurred'),
            ),
          );
        }
      },
    );
  }

  bool _validateInput(String value) {
    final limit = 6;
    final permittedChars = "[1-9][0-9]{5}";

    if (value.length != limit) {
      return false;
    }

    try {
      final regex = RegExp('^$permittedChars+\$');
      if (!regex.hasMatch(value)) {
        return false;
      }
    } catch (e) {
      return true;
    }

    return true;
  }

  @override
  void dispose() {
    // Only dispose our own controller, not the external one
    _pincodeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = init || onboardingStepsProvider.loading;

    return Scaffold(
      appBar: AppBar(
        elevation: 6,
        leading: InkWell(
          onTap: () {
            if (onboardingQuestionResponse?.moduleId != null) {
              onboardingStepsProvider.goBackToPreviousQuestion(
                context,
                onboardingQuestionResponse!.moduleId!,
              );
            } else {
              Navigator.of(context).pop();
            }
          },
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.n80,
          ),
        ),
      ),
      body: (loading || currentPosition == null || isLoading)
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        GoogleMap(
                          onMapCreated: _onMapCreated,
                          onCameraMoveStarted: () {
                            if (_isProgrammaticCameraMove) {
                              return;
                            }
                            _shouldReverseGeocodeOnIdle = true;
                            selectedPlaceId = null;
                          },
                          onCameraIdle: () async {
                            // Reset programmatic flag
                            if (_isProgrammaticCameraMove) {
                              _isProgrammaticCameraMove = false;
                              return;
                            }

                            if (!_shouldReverseGeocodeOnIdle ||
                                currentPosition == null) {
                              return;
                            }
                            await _getAddressFromLatLng(currentPosition!);
                            await _checkServiceability(currentPosition!);
                            if (mounted) {
                              setState(() {});
                            }
                          },
                          scrollGesturesEnabled: true,
                          zoomControlsEnabled: true,
                          rotateGesturesEnabled: true,
                          tiltGesturesEnabled: true,
                          onCameraMove: (CameraPosition position) async {
                            currentPosition = position.target;
                            latitude = position.target.latitude;
                            longitude = position.target.longitude;
                          },
                          initialCameraPosition: CameraPosition(
                            target: currentPosition!,
                            zoom: zoomValue,
                          ),
                          myLocationButtonEnabled: false,
                          myLocationEnabled: true,
                        ),
                        Positioned(
                          bottom: 12.h,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Material(
                              color: AppColors.n0,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  await Future.delayed(
                                      const Duration(milliseconds: 100));
                                  await locateMe();
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16.w, vertical: 9.h),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _locateMeImageUrl != null
                                          ? RemoteImageHandler(
                                              imageUrl: _locateMeImageUrl ?? "")
                                          : Icon(
                                              Icons.my_location,
                                              size: 16.r,
                                            ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        "Locate me",
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(color: Colors.black),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Progress bar for onboarding flow
                        Padding(
                          padding: EdgeInsets.only(top: 13.h),
                          child: OnboardingProgressBar(
                              progressValue: _progressValue),
                        ),
                        if (!loading)
                          Positioned.fill(
                            top: -20,
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.p20.withAlpha(77),
                                ),
                                width: 78.h,
                                child: _mapMarkerImageUrl != null
                                    ? RemoteImageHandler(
                                        imageUrl: _mapMarkerImageUrl ?? "")
                                    : Image.asset(
                                        "assets/pngs/map_marker.png",
                                        color: AppColors.brand,
                                        scale: 1,
                                      ),
                              ),
                            ),
                          ),
                        if (!loading)
                          Positioned.fill(
                            top: 103.h,
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: AppColors.n30,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  languageProvider.getMessage(
                                      "change_location_map_marker_info",
                                      "Move the pin and place accurately"),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 8.h,
                      ),
                      Center(
                        child: Container(
                          height: 4.h,
                          width: 35.w,
                          decoration: BoxDecoration(
                              color: const Color(0xffD1D1D1),
                              // TODO color not found
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      // Todo: check the key
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.getMessage(
                                  "address_information", "Address Information"),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            SizedBox(height: 16.h),
                            const Divider(
                              color: AppColors.n30,
                              height: 0,
                            ),
                            SizedBox(height: 16.h),
                          ],
                        ),
                      ),
                      Container(
                        color:
                            !isServiceable ? AppColors.r0 : Colors.transparent,
                        padding: !isServiceable
                            ? EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 7.h)
                            : EdgeInsets.symmetric(horizontal: 16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (addressLine1 != null &&
                                addressLine1!.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      addressLine1!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                  ),
                                  ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxWidth: 0.5.sw),
                                    child: TextButton(
                                      onPressed: () async {
                                        await showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            constraints: BoxConstraints(
                                              maxHeight: 0.8.sh,
                                              minHeight: 0.8.sh,
                                            ),
                                            builder: (_) {
                                              return PlaceSearch(
                                                fetchPlaceDetails: (val) async {
                                                  await fetchPlaceDetails(
                                                      val ?? "");
                                                },
                                                locateMe: locateMe,
                                              );
                                            });
                                        if (!mounted) return;
                                        FocusScope.of(context).unfocus();
                                        setState(() {});
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.brand,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.r),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10.w, vertical: 4.h),
                                        child: Text(
                                          // Todo: check the key
                                          languageProvider.getMessage(
                                              "map_change_location", "Change"),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                  color: AppColors.brand),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (addressLine2 != null &&
                                addressLine2!.isNotEmpty) ...[
                              SizedBox(height: 12.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      addressLine2!,
                                      textAlign: TextAlign.start,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xff080A29),
                                          ),
                                      // Todo: color doesn't exist
                                    ),
                                  ),
                                ],
                              ),
                              if (isServiceable && pincode == null)
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 16.h,
                                  ),
                                  child: OnboardingQuestion(
                                    questionKey: "please_enter_pincode",
                                    questionDefault: "Please enter pincode",
                                    mandatory: true,
                                    error: pincode == null
                                        ? languageProvider.getMessage(
                                            "pincode_required",
                                            "Pincode is required")
                                        : "",
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 3.14.w, vertical: 6.18.h),
                                    answer: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _pincodeController,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                  6),
                                            ],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText:
                                                  languageProvider.getMessage(
                                                      'please_enter_pincode',
                                                      "Please enter pincode"),
                                              hintStyle: AppTextTheme.hintStyle,
                                              border:
                                                  const OutlineInputBorder(),
                                            ),
                                            onChanged: (value) {
                                              final isValid =
                                                  _validateInput(value);
                                              if (isValid) {
                                                pincode = value;
                                                showToast();
                                              } else {
                                                pincode = null;
                                              }
                                              setState(() {});
                                            },
                                            enabled: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (!isServiceable) ...[
                                SizedBox(height: 12.h),
                                Text(
                                  "We do not operate in this area yet. Please select the nearest location.",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: AppColors.r50,
                                      ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 12.h),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: (loading ||
                                  buttonLoading ||
                                  isLoading ||
                                  !isServiceable ||
                                  pincode == null ||
                                  pincode?.isEmpty == true)
                              ? null
                              : () async {
                                  setState(() {
                                    buttonLoading = true;
                                  });
                                  await _submitLocationAnswer();
                                  if (mounted) {
                                    setState(() {
                                      buttonLoading = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                          ),
                          child: buttonLoading || isLoading
                              ? const CupertinoActivityIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  languageProvider.getMessage(
                                      'save_address_details',
                                      "Save address details"),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void showToast() {
    Widget toast = Container(
      padding: EdgeInsets.symmetric(
        vertical: 12.h,
        horizontal: 26.w,
      ),
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE7E9F4), // Hex color for shadow
            offset: Offset(0, 4), // Horizontal and vertical offset
            blurRadius: 4, // Blur radius
            spreadRadius: 0, // Spread radius
          ),
        ],
        borderRadius: BorderRadius.circular(12.r),
        color: const Color(0xFF1F1F20).withValues(alpha: 0.8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 7.5.h,
            backgroundColor: Color(0xFF40935A),
            child: Icon(
              Icons.check,
              color: Color(0xFFD9D9D9),
              size: 10.r,
            ),
          ),
          SizedBox(
            width: 10.w,
          ),
          Flexible(
            child: Text(
              "Pincode added successfully",
              softWrap: true,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xffF5EFF7),
                  ),
            ),
          ),
        ],
      ),
    );
    showCustomToast(widget: toast, bottomPosition: 48.h, context: context);
  }
}

class PlaceSearch extends StatefulWidget {
  final Function(String? placeId) fetchPlaceDetails;
  final VoidCallback locateMe;

  const PlaceSearch({
    super.key,
    required this.fetchPlaceDetails,
    required this.locateMe,
  });

  @override
  State<PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<PlaceSearch> {
  TextEditingController placeTextController = TextEditingController();
  List<dynamic>? placePredictions;
  bool predictionsLoading = false;

  Future<void> placeAutocomplete(String query) async {
    setState(() {
      predictionsLoading = true;
    });
    try {
      final response = await HttpService().get(
          GlobalState().serverPath(
              "api/v1/geos/locations/suggestion?search_term=$query"),
          headers: {});
      if (response.data is List) {
        placePredictions = List.from(response.data as List);
      } else {
        placePredictions = response.data;
      }
    } catch (_) {
      placePredictions = [];
    } finally {
      if (mounted) {
        setState(() {
          predictionsLoading = false;
        });
      } else {
        predictionsLoading = false;
      }
    }
  }

  @override
  void dispose() {
    placeTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: CommonBottomSheetSetup(
        horizontalPadding: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 32.h),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: TextFormField(
                    autofocus: true,
                    controller: placeTextController,
                    maxLines: 1,
                    onChanged: (val) async {
                      await placeAutocomplete(val);
                    },
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      suffixIcon: placeTextController.text.isNotEmpty
                          ? InkWell(
                              onTap: () {
                                setState(() {
                                  placeTextController.text = "";
                                  placePredictions?.clear();
                                });
                              },
                              child: Transform.scale(
                                scale: 0.4,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xffEAEAF1),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.brand,
                                    size: 40,
                                  ),
                                ),
                              ),
                            )
                          : null,
                      hintText: "Search for your location",
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            setState(() {
                              Navigator.of(context).pop();
                            });
                            await Future.delayed(
                                const Duration(milliseconds: 100));
                            widget.locateMe();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.my_location),
                                Gap.gap8w,
                                Text(
                                  "Current Location",
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              Navigator.of(context).pop();
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.map_outlined),
                                Gap.gap8w,
                                Text(
                                  "Locate on Map",
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              height: 10.h,
              color: AppColors.n20,
            ),
            SizedBox(height: 16.h),
            if (predictionsLoading)
              Center(child: const CupertinoActivityIndicator())
            else if (placePredictions != null)
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: placePredictions!.length,
                  itemBuilder: (BuildContext context, int index) {
                    return InkWell(
                      onTap: () async {
                        placeTextController.clear();
                        final pId = placePredictions?[index]["place_id"];
                        widget.fetchPlaceDetails(pId);
                        placePredictions?.clear();
                        Navigator.of(context).pop();
                      },
                      child: ListTile(
                        dense: true,
                        titleAlignment: ListTileTitleAlignment.top,
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xff969696),
                            size: 25,
                          ),
                        ),
                        title: Text(
                          placePredictions![index]["name"],
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              placePredictions![index]["description"],
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SizedBox(height: 14.h),
                            const Divider(
                              color: Color(0xffD8D8D8),
                              height: 0,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

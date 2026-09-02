import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/models/go_live/hotspots.dart';
import 'package:snabbit_runner/models/hood.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/go_live_flow_controller.dart';
import 'package:snabbit_runner/pages/signup/onboarding_screen.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/pages/selfie_capture_page.dart';
import 'package:snabbit_runner/pages/signup/training_progress.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/server_requests/go_live_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/navigation_utils.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/go_live/dropdown_list.dart';
import '../../../utils/colors.dart';
import '../../../widgets/map_job_location.dart';
import '../../providers/language_provider.dart';
import '../../services/server_requests/maps_http.dart';
import 'package:snabbit_runner/utils/error_handler.dart'
    as responseErrorHandler;

class ClusterDetailsPage extends StatefulWidget {
  static const String routeName = '/cluster-details';

  const ClusterDetailsPage({super.key});

  @override
  State<ClusterDetailsPage> createState() => _ClusterDetailsPageState();
}

class _ClusterDetailsPageState extends State<ClusterDetailsPage> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  final FlutterTts flutterTts = FlutterTts();
  String? hotspotAddress;
  List<HotSpot>? _hotspots;
  HotSpot? _selectedHotspot;
  String? clusterName;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    //get hotspots
    try {
      setState(() {
        loading = true;
      });

      // For V2 flow, pass hood_id from verified shift
      final goLiveV2Provider = _tryGetGoLiveV2Provider();
      final hoodId = goLiveV2Provider?.selectedShift?.hoodId;

      Response? response = await GoLiveHttp.getAvailableHotspots(
        hoodId: hoodId,
      );
      if (response != null && response.statusCode == 200) {
        final res = HotspotsResponse.fromJson(response.data);
        _hotspots = res.hotspots;
        clusterName = res.clusterName;
        if (_hotspots != null && _hotspots?.length == 1) {
          _selectedHotspot = _hotspots?.first;
          _getAddressFromLatLng();
        }

        setState(() {});
      } else {
        responseErrorHandler.ErrorHandler.handleResponseError(
          response: response,
          context: context,
          onError: (context, responseError) {
            showSnackbar(context, responseError.errors?.first.message ?? '');
          },
        );
      }
    } catch (e) {
      showSnackbar(context, "Something went wrong fetching hotspots");
    }
  }

  Future<void> _speakAddress() async {
    await flutterTts.speak(hotspotAddress ?? "");
  }

  bool addressLoading = false;

  Future<void> _getAddressFromLatLng() async {
    try {
      setState(() {
        addressLoading = true;
      });
      final response = await MapsHttp.fetchUrl(
          'api/v1/geos/locations/details?lat=${_selectedHotspot?.lat}&lng=${_selectedHotspot?.lng}&skip_serviceability_check=true');
      if (response != null && response.statusCode == 200) {
        final data = response.data;
        hotspotAddress = data['address']['address_text'];
      } else {
        // print('Request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (_selectedHotspot != null) {
        showSnackbar(context, "Failed to fetch address");
      }
    } finally {
      addressLoading = false;
      setState(() {});
    }
  }

  /// Safely get GoLiveV2Provider if available, returns null otherwise
  GoLiveV2Provider? _tryGetGoLiveV2Provider() {
    try {
      final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
      return provider;
    } catch (e) {
      return null;
    }
  }

  void _confirmCluster() {
    // Check if coming from V2 flow (provider has selected shift data)
    final goLiveV2Provider = _tryGetGoLiveV2Provider();

    final isV2Flow = goLiveV2Provider?.selectedShift != null;

    // If V2 flow, show confirmation modal first
    if (isV2Flow) {
      _showShiftLockConfirmationModal();
    } else {
      // V1 flow - proceed directly
      _proceedWithConfirmation();
    }
  }

  void _showShiftLockConfirmationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.n0,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
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
            Icon(
              Icons.lock_outline,
              size: 56.sp,
              color: AppColors.n80,
            ),
            SizedBox(height: 24.h),

            // Title
            Text(
              languageProvider.getMessage(
                'go_live_v2_shift_lock_confirmation',
                'Are you sure?\nYour shift will be locked here',
              ),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF000000),
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),

            // Buttons Row
            Row(
              children: [
                // No button (red)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935), // Red
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      languageProvider.getMessage(
                        'go_live_v2_no',
                        'No',
                      ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.n0,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                // Yes button (green)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047), // Green
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _proceedWithConfirmation();
                    },
                    child: Text(
                      languageProvider.getMessage(
                        'go_live_v2_yes',
                        'Yes',
                      ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.n0,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Future<void> _proceedWithConfirmation() async {
    // Implement confirmation logic here
    try {
      setState(() {
        loading = true;
      });

      // Check if coming from V2 flow (provider has selected shift data)
      final goLiveV2Provider = _tryGetGoLiveV2Provider();
      final isV2Flow = goLiveV2Provider?.selectedShift != null;

      // If V2 flow, call confirm_shift API first before proceeding
      if (isV2Flow && goLiveV2Provider != null) {
        final confirmResponse = await goLiveV2Provider.confirmShift();
        if (confirmResponse == null || !confirmResponse.success) {
          // If PARTNER_ALREADY_ONBOARDED error, silently skip and continue
          // This means the user has already confirmed their shift, so we can proceed
          if (goLiveV2Provider.isPartnerAlreadyOnboardedOnConfirm) {
            // Continue with the flow - partner already has a shift confirmed
          } else {
            setState(() {
              loading = false;
            });
            showSnackbar(
              context,
              goLiveV2Provider.confirmShiftError ?? 'Failed to confirm shift',
            );
            return;
          }
        }
      }

      // Then call updateHotspot (existing V1 logic)
      final response =
          await GoLiveHttp.updateHotspot(hotspotId: _selectedHotspot?.id);
      setState(() {
        loading = false;
      });
      if (response?.statusCode != 200) {
        responseErrorHandler.ErrorHandler.handleResponseError(
          response: response,
          context: context,
          onError: (context, responseError) {
            showSnackbar(context, responseError.errors?.first.message ?? '');
          },
        );
        return;
      }
    } catch (_) {
      loading = false;
    }
    _showSelfieCaptureBottomSheet();
  }

  void _showSelfieCaptureBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return CommonBottomSheetSetup(
          child: Column(
            children: [
              SizedBox(height: 35.h),
              Image.asset(
                'assets/pngs/selfie_icon.png',
                height: 85.h,
              ),
              SizedBox(height: 28.h),
              Text(
                languageProvider.getMessage(
                  'selfie_snabbit_uniform_message',
                  'Please take a selfie in your Snabbit uniform',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 12.h),
              Text(
                languageProvider.getMessage(
                  'id_card_message',
                  'This will be your ID card picture ',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 19.sp,
                      color: AppColors.n70,
                    ),
              ),
              SizedBox(height: 43.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => SelfieCapturePage(
                          onSubmit: (File image) async {
                            Response? response = await RunnerHttp.goLive(image);
                            if (response != null &&
                                response.statusCode == 200 &&
                                context.mounted) {
                              GlobalState().showSnabbitCongratsPopup = true;
                              Navigator.pushNamedAndRemoveUntil(context,
                                  PartnerHome.routeName, (route) => false);
                            } else {
                              try {
                                final resError =
                                    ResponseError.fromMap(response?.data);
                                if (resError.errors?.isNotEmpty == true) {
                                  _handleSelfieResponseErrors(resError);
                                } else {
                                  showSnackbar(
                                    context,
                                    "Something went wrong (${response?.statusCode}) - ${GlobalState().appError.value.description ?? ""}",
                                  );
                                }
                              } catch (e) {
                                showSnackbar(
                                  context,
                                  "Something went wrong ${GlobalState().appError.value.description ?? ""}",
                                );
                              }
                            }
                          },
                          onCancel: () {},
                        ),
                      ),
                    );
                  },
                  child: Text(
                    languageProvider.getMessage(
                      'take_selfie',
                      'Take selfie',
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        );
      },
    );
  }

  // The optimized function to handle errors
  void _handleSelfieResponseErrors(ResponseError resError) {
    // Check if there are any errors to process
    final errors = resError.errors;
    if (errors == null || errors.isEmpty) {
      return;
    }

    // Iterate over the errors once to find the first matching one
    for (final error in errors) {
      if (error.errorMessageCode == AppStrings.retakeSelfie) {
        List<String> errors = (error.data as List).cast<String>();
        showSelfieError(errors, context);
        return; // Exit after handling the first error
      } else if (error.errorMessageCode ==
          AppStrings.redirectToPotentialEarnings) {
        NavigationUtils.openTrainingWebView(
          context: context,
          popUntil: true,
        );
        GoLiveFlowController.startFlow(context);
        showSnackbar(
          context,
          error.message ?? '',
        );
        return; // Exit after handling the first error
      } else {
        showSnackbar(
          context,
          error.message ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
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
          "In Training",
          style: textTheme.bodyLarge,
        ),
      ),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: _confirmCluster,
            child: Text(
              languageProvider.getMessage(
                'i_confirm',
                'I confirm',
              ),
            ),
          ),
        ),
      ],
      body: loading
          ? const Center(child: CupertinoActivityIndicator())
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 33.h,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 30.w,
                  vertical: 35.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.n0,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cluster name
                    Text(
                      languageProvider.getMessage(
                          "your_cluster", "Your Cluster"),
                      style: textTheme.labelLarge,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      clusterName ?? "",
                      style: textTheme.displayLarge?.copyWith(
                        fontSize: 28.sp,
                        color: AppColors.n90,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    (_hotspots == null || _hotspots!.isEmpty)
                        ? const Text("Hotspots unavailable")
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 36.h),
                              if (_hotspots != null &&
                                  (_hotspots?.length ?? 0) > 1)
                                DropDownList<HotSpot>(
                                  label: languageProvider.getMessage(
                                      'select_hotspot', "Select Hotspot"),
                                  items: _hotspots ?? [],
                                  initialSelection: _selectedHotspot,
                                  onSelectionChanged: (value) {
                                    _selectedHotspot = value;
                                    if (mounted) {
                                      setState(() {});
                                    }
                                    _getAddressFromLatLng();
                                    // Update user profile with selected hotspot
                                  },
                                  itemNameBuilder: (item) => item.name ?? '',
                                  padding: EdgeInsets.only(
                                    bottom: 12.h,
                                  ),
                                ),
                              // Hood Location
                              if (_selectedHotspot != null)
                                Text(
                                  "Hotspot Location - ${_selectedHotspot?.name ?? ''}",
                                  style: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              SizedBox(height: 12.h),

                              // Address
                              addressLoading
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: 16.h),
                                        child:
                                            const CupertinoActivityIndicator(),
                                      ),
                                    )
                                  : hotspotAddress != null &&
                                          hotspotAddress?.trim().isNotEmpty ==
                                              true
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              hotspotAddress ?? "",
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: AppColors.n80,
                                              ),
                                            ),
                                            SizedBox(height: 12.h),

                                            // Speak Address button
                                            OutlinedButton(
                                              onPressed: _speakAddress,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.n90,
                                                side: const BorderSide(
                                                    color: AppColors.n40),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 16.w,
                                                  vertical: 10.h,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.volume_up),
                                                  SizedBox(width: 8.w),
                                                  Text(
                                                    languageProvider.getMessage(
                                                      "speak_address",
                                                      "Speak address",
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 24.h),
                                          ],
                                        )
                                      : const SizedBox.shrink(),

                              // Map
                              if (_selectedHotspot != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: SizedBox(
                                    height: 170.h,
                                    width: double.infinity,
                                    child: MapJobLocation(
                                      markerPosition: LatLng(
                                        _selectedHotspot?.lat ?? 0,
                                        _selectedHotspot?.lng ?? 0,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}

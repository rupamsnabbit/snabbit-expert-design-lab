import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/go_live/device_testing.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/go_live/permission_button.dart';
import 'package:snabbit_runner/widgets/location_permission_confirmation.dart';

class PhoneIntegrityCheck extends StatefulWidget {
  static const String routeName = '/phone-integrity-check';

  const PhoneIntegrityCheck({super.key});

  @override
  State<PhoneIntegrityCheck> createState() => _PhoneIntegrityCheckState();
}

class _PhoneIntegrityCheckState extends State<PhoneIntegrityCheck> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  final TextEditingController childNameController = TextEditingController();
  bool init = true;
  bool locationAccess = false;
  PermissionStatus? cameraStatus;
  PermissionStatus? micStatus;
  bool cameraLoading = false;
  bool locationLoading = false;
  bool micLoading = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      Future(() async {
        await checkCameraPermission();
        await checkMicPermission();
        await checkLocationAccess();
        // Initialize any required data or state here
      });
    }
    super.didChangeDependencies();
  }

  void _continue() {
    // Navigate to next page or update status
    Navigator.of(context).pushNamed(DeviceTesting.routeName);
  }

  bool _canProceed() {
    // Check if all required permissions are granted
    return cameraAccess && locationAccess && micAccess &&
        !cameraLoading && !locationLoading && !micLoading;
  }

  void _allowPermissions(){
    Future(() async{
      await Future.wait([
        if(!cameraAccess) requestCameraPermission(),
        if(!micAccess) requestMicPermission(),
      ]);
    }).then((value) {
      if (!locationAccess) {
        showCompulsoryPermissionDialog();
      }
    },);
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
              child:_canProceed() ? ElevatedButton(
                onPressed: _continue,
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
              ):ElevatedButton(
                onPressed: _allowPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.n0,
                ),
                child: Text(
                  languageProvider.getMessage(
                    "allow_permissions",
                    "Allow Permissions",
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
            // horizontal: 20.w,
            vertical: 16.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.n0,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
             Padding(padding: EdgeInsets.symmetric(horizontal: 16.w,),
               child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min,
               children: [
                 Flexible(
                   child: FittedBox(
                     child: Text(
                       languageProvider.getMessage(
                         "phone_integrity_check_title",
                         "We need a couple of things to get started",
                       ),
                       style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                         fontWeight:
                         FontWeight.w600, // CSS: font-weight: 600; (Semi Bold)
                         fontStyle: FontStyle
                             .normal, // CSS: font-style: Semi Bold; (Flutter uses FontWeight for "Semi Bold")
                         fontSize: 16.sp, // CSS: font-size: 16px;
                         height: 18 /
                             16, // CSS: line-height: 18px; (calculated as line-height / font-size)
                         letterSpacing: 0.0, // CSS: letter-spacing: 0px;
                       ),
                     ),
                   ),
                 ),
                 SizedBox(height: 6.18.h,),
                 Flexible(
                   child: FittedBox(
                     child: Text(
                       languageProvider.getMessage(
                         "phone_integrity_check_subtitle",
                         "We need following set of permissions to test your device",
                       ),
                       style: Theme.of(context)
                           .textTheme
                           .titleMedium
                           ?.copyWith(
                         fontWeight:
                         FontWeight.w500, // CSS: font-weight: 500; (Medium)
                         fontStyle: FontStyle
                             .normal, // CSS: font-style: Medium; (Flutter uses FontWeight for "Medium")
                         fontSize: 16.0, // CSS: font-size: 16px;
                         height:
                         1.0, // CSS: line-height: 100%; (calculated as 100% of font size, i.e., 1.0)
                         letterSpacing: -1.0, // CSS: letter-spacing: -1px;
                       ),
                     ),
                   ),
                 ),
               ],
             ),
             ),
              GridView.count(
                // Changed to GridView.count
                crossAxisCount: 2,
                // 2 columns
                shrinkWrap: true,
                // Wrap content
                mainAxisSpacing: 20.h,
                // Spacing between rows
                crossAxisSpacing: 20.w,
                // Spacing between columns
                padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
                // Padding around the grid
                childAspectRatio: 155 / 60,
                children: [
                  PermissionButton(
                    permissionName:
                        languageProvider.getMessage('camera', 'Camera'),
                    actionText: getStatusText(cameraAccess),
                    icon: AssetConstants.famiconsCameraOutlined,
                    actionTextColor:
                        cameraAccess ? AppColors.g30 : AppColors.r40,
                    onPressed: () async {
                      if (!cameraAccess) {
                        await requestCameraPermission();
                      }
                      // Implement logic to request camera permission
                    },
                    isLoading: cameraLoading,
                  ),
                  PermissionButton(
                    permissionName:
                        languageProvider.getMessage('location', 'Location'),
                    actionText: getStatusText(locationAccess),
                    icon: AssetConstants.locationPinOutlined,
                    actionTextColor:
                        locationAccess ? AppColors.g30 : AppColors.r40,
                    // Example of custom color
                    onPressed: () async {
                      if (!locationAccess) {
                        showCompulsoryPermissionDialog();
                      }
                      // Implement logic to request location permission
                    },
                    isLoading: locationLoading,
                  ),
                  PermissionButton(
                    permissionName:
                        languageProvider.getMessage('microphone', 'Microphone'),
                    actionText: getStatusText(micAccess),
                    icon: AssetConstants.micOutlined,
                    actionTextColor: micAccess ? AppColors.g30 : AppColors.r40,
                    // Example of custom color
                    onPressed: () async {
                      if (!micAccess) {
                        requestMicPermission();
                      }
                      // Implement logic to request location permission
                    },
                    isLoading: micLoading,
                  ),
                ],
              ),
              SizedBox(
                height: 12.h,
              )
            ],
          ),
        ),
      ),
    );
  }

  String getStatusText(bool condition) {
    String key, text;
    if (condition) {
      key = 'allowed';
      text = 'Allowed';
    } else {
      key = "allow_access";
      text = 'Allow Access';
    }
    return languageProvider.getMessage(key, text);
  }

  bool get cameraAccess => cameraStatus == PermissionStatus.granted;
  bool get micAccess => micStatus == PermissionStatus.granted;

  Future<void> checkLocationAccess() async {
    try {
      setState(() {
        locationLoading = true;
      });
      final deniedForever = await isLocationDeniedForever();
      final notAlways = await isLocationAlwaysNotGranted();
      final preciseLocation = await isPreciseLocationEnabled();
      setState(() {
        locationLoading = false;
        locationAccess = !deniedForever && !notAlways && preciseLocation;
      });
    } catch (e) {
      MonitoringServiceHelper.logError(
        'Location Permission Check Error',
        {
          'component': 'PhoneIntegrityCheck',
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      setState(() {
        locationLoading = false;
        locationAccess = false;
      });
    }
  }

  Future<void> checkCameraPermission() async {
    try {
      setState(() {
        cameraLoading = true;
      });
      // Check only camera permission
      final camera = await Permission.camera.status;

      // Log the permission check result
      MonitoringServiceHelper.logInfo(
        'Camera Permission Check',
        {
          'component': 'PhoneIntegrityCheck',
          'camera status': camera.name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        setState(() {
          cameraStatus = camera;
          cameraLoading = false;
        });
      }
    } catch (e) {
      // On error, set as denied and log
      MonitoringServiceHelper.logError(
        'Camera Permission Check Error',
        {
          'component': 'PhoneIntegrityCheck',
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      if (mounted) {
        setState(() {
          cameraStatus = PermissionStatus.denied;
        });
      }
    }
  }

  Future<void> requestCameraPermission() async {
    setState(() {
      cameraLoading = true;
    });

    try {
      // Request only camera permission
      PermissionStatus cameraStatus = await Permission.camera.request();

      // Log the permission request result
      MonitoringServiceHelper.logInfo(
        'Camera Permission Request',
        {
          'component': 'MiniCamera',
          'camera status': cameraStatus.name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (cameraStatus.isGranted || cameraStatus.isDenied) {
        setState(() {
          this.cameraStatus = cameraStatus;
        });
      } else if (cameraStatus.isPermanentlyDenied) {
        openAppSettings();
      }
    } finally {
      if (mounted) {
        setState(() {
          cameraLoading = false;
        });
      }
    }
  }

  Future<void> checkMicPermission() async {
    try {
      setState(() {
        micLoading = true;
      });
      // Check only microphone permission
      final mic = await Permission.microphone.status;

      // Log the permission check result
      MonitoringServiceHelper.logInfo(
        'Microphone Permission Check',
        {
          'component': 'PhoneIntegrityCheck',
          'microphone status': mic.name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        setState(() {
          micStatus = mic;
          micLoading = false;
        });
      }
    } catch (e) {
      MonitoringServiceHelper.logError(
        'Microphone Permission Check Error',
        {
          'component': 'PhoneIntegrityCheck',
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      if (mounted) {
        setState(() {
          micStatus = PermissionStatus.denied;
          micLoading = false;
        });
      }
    }
  }

  Future<void> requestMicPermission() async {
    setState(() {
      micLoading = true;
    });
    try {
      // Request only microphone permission
      PermissionStatus micStatusResult = await Permission.microphone.request();

      // Log the permission request result
      MonitoringServiceHelper.logInfo(
        'Microphone Permission Request',
        {
          'component': 'PhoneIntegrityCheck',
          'microphone status': micStatusResult.name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (micStatusResult.isGranted || micStatusResult.isDenied) {
        setState(() {
          micStatus = micStatusResult;
        });
      } else {
        openAppSettings();
      }
    } finally {
      if (mounted) {
        setState(() {
          micLoading = false;
        });
      }
    }
  }
}

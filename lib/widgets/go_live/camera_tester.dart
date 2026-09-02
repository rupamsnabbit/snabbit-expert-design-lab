import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

class CameraTester extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onFailure;
  const CameraTester({
    super.key,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<CameraTester> createState() => _CameraTesterState();
}

class _CameraTesterState extends State<CameraTester>
    with WidgetsBindingObserver {
  List<CameraDescription> cameras = [];
  CameraController? controller;
  bool _isCameraInitialized = false;
  PermissionStatus? camerastatus;
  final resolutionPresets = ResolutionPreset.values;
  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;
  bool init = true;
  bool loading = true;
  bool _wentToSettings = false;

  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;

  Future<void> initProcess() async {
    await requestCameraPermission();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Null out [controller] before disposing to prevent race conditions where
  /// CameraX accesses the disposed ImageReaderSurfaceProducer via a stale
  /// reference, which causes NullPointerException.
  void _disposeCamera() {
    final ctrl = controller;
    controller = null;
    ctrl?.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dispose camera controller when app goes to background to prevent
    // CameraX plugin from trying to access display from non-visual context
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (controller != null && controller!.value.isInitialized) {
        _disposeCamera();
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
      }
    } else if (state == AppLifecycleState.resumed && mounted) {
      if (_wentToSettings) {
        _wentToSettings = false;
        setState(() {
          loading = true;
        });
        requestCameraPermission().then((_) {
          if (mounted) {
            setState(() {
              loading = false;
            });
          }
        }).catchError((e) {
          MonitoringServiceHelper.logError(
            'Camera Permission Request Failed on Resume',
            {
              'component': 'MiniCamera',
              'error': e.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          if (mounted) {
            setState(() {
              loading = false;
            });
          }
        });
      } else if (camerastatus?.isGranted == true && !_isCameraInitialized) {
        // Reinitialize camera after returning from normal background
        setState(() {
          loading = true;
        });
        getCameras().then((_) {
          if (mounted) {
            setState(() {
              loading = false;
            });
          }
        }).catchError((_) {
          if (mounted) {
            setState(() {
              loading = false;
            });
          }
        });
      }
    }
  }

  Future<void> requestCameraPermission() async {
    // Set loading to true before showing permission dialogs
    setState(() {
      loading = true;
    });

    try {
      // Request both camera and microphone permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      PermissionStatus cameraStatus =
          statuses[Permission.camera] ?? PermissionStatus.denied;
      PermissionStatus micStatus =
          statuses[Permission.microphone] ?? PermissionStatus.denied;

      // Log the permission request results
      MonitoringServiceHelper.logInfo(
        'Camera and Microphone Permission Request',
        {
          'component': 'MiniCamera',
          'camera status': cameraStatus.name,
          'microphone status': micStatus.name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Only proceed if both permissions are granted
      if (cameraStatus.isGranted && micStatus.isGranted) {
        setState(() {
          camerastatus = cameraStatus;
        });
        await getCameras();
      } else if (cameraStatus.isPermanentlyDenied ||
          micStatus.isPermanentlyDenied) {
        // One or both permissions permanently denied
        setState(() {
          camerastatus = PermissionStatus.permanentlyDenied;
        });
        widget.onFailure();
      } else {
        // Regular denial for one or both
        setState(() {
          camerastatus = PermissionStatus.denied;
        });
        widget.onFailure();
      }
    } finally {
      // Always set loading back to false after permissions dialog closes
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> getCameras() async {
    cameras = await availableCameras();
    try {
      await onNewCameraSelected(cameras[1]);
    } catch (e) {
      MonitoringServiceHelper.logError(
        'Primary Camera Selection Failed',
        {
          'component': 'MiniCamera',
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      try {
        await onNewCameraSelected(cameras[0]);
        MonitoringServiceHelper.logInfo(
          'Fallback Camera Selection Success',
          {
            'component': 'MiniCamera',
            'selectedCamera': 'fallback',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (err) {
        MonitoringServiceHelper.logError(
          'Camera Initialization Failed',
          {
            'component': 'MiniCamera',
            'error': err.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        debugPrint("error ${e.toString()}");
      }
    }
    setState(() {});
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;
    // Instantiating the camera controller
    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // Dispose the previous controller
    await previousCameraController?.dispose();

    // Replace with the new controller
    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize controller
    try {
      await cameraController.initialize();
      takePicture(context);
      MonitoringServiceHelper.logInfo(
        'Camera Controller Initialized',
        {
          'component': 'MiniCamera',
          'cameraDirection': cameraDescription.lensDirection.toString(),
          'resolution': currentResolutionPreset.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } on CameraException catch (e) {
      MonitoringServiceHelper.logError(
        'Camera Controller Initialization Failed',
        {
          'component': 'MiniCamera',
          'error': e.toString(),
          'cameraDirection': cameraDescription.lensDirection.toString(),
          'resolution': currentResolutionPreset.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('Error initializing camera: $e');
      widget.onFailure();
    }

    // Update the Boolean
    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  Future takePicture(BuildContext context) async {
    XFile? buildingPhoto;
    final CameraController? cameraController = controller;
    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }
    try {
      await cameraController.takePicture().then((file) async {
        widget.onSuccess();
      });
    } on CameraException catch (e) {
      widget.onFailure();
      print('Error occured while taking picture: $e');

      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return camerastatus?.isGranted == true
        ? _isCameraInitialized &&
                controller != null &&
                controller!.value.isInitialized
            ? Center(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          height: 139.h,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: CameraPreview(controller!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: loading
                    ? const CupertinoActivityIndicator()
                    : const Text('Camera initialization failed.'),
              )
        : const SizedBox.shrink();
  }
}

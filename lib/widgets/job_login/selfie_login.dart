import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/selfie_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/job_login/selfie_preview.dart';

/// Rough threshold (in logical pixels) on the window's *longest* side,
/// separating a Picture-in-Picture window from a normal app window.
///
/// We key off the longest side, not the shortest: a phone in portrait has
/// a shortest side of only ~360–430 dp (which would false-positive as PiP),
/// but its longest side is always ≥ ~640 dp. A PiP window is small in both
/// dimensions — its longest side is typically ≤ ~400 dp. 500 dp sits in the
/// safe gap between the two. Conservative on purpose: a false negative just
/// means we don't proactively free camera surfaces in PiP; a false positive
/// could needlessly tear down the camera in split-screen.
const double kPipLongestSideThresholdDp = 500.0;

/// The kind of Picture-in-Picture transition implied by a window resize.
enum PipTransition { entered, exited, none }

/// Pure classification of a window-size change into a PiP transition.
///
/// Extracted from [_SelfieForLoginState.didChangeMetrics] so the threshold
/// logic is unit-testable without the camera plugin's platform channels.
/// [previous] is null on the first metrics callback (no prior size yet).
PipTransition classifyPipTransition(
  Size? previous,
  Size current, {
  double threshold = kPipLongestSideThresholdDp,
}) {
  if (previous == null) return PipTransition.none;
  final wasPip = previous.longestSide < threshold;
  final isPip = current.longestSide < threshold;
  if (!wasPip && isPip) return PipTransition.entered;
  if (wasPip && !isPip) return PipTransition.exited;
  return PipTransition.none;
}

class SelfieForLogin extends StatefulWidget {
  static const routeName = "selfie-login";
  final bool isForMarkArrival;

  const SelfieForLogin({super.key, this.isForMarkArrival = false});

  @override
  State<SelfieForLogin> createState() => _SelfieForLoginState();
}

class _SelfieForLoginState extends State<SelfieForLogin>
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

  late LoginSelfieProvider loginSelfieProvider;
  late LoginSelfie loginSelfie;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;

  // Guards against concurrent init chains spawning multiple orphan
  // CameraControllers. Vivo/other devices with a 3-surface CameraX limit
  // fail immediately if even one previous controller hasn't fully released.
  bool _initInFlight = false;

  // Tracks the in-flight dispose from didChangeAppLifecycleState pause —
  // which can't be awaited there. Reinit awaits this before binding new
  // surfaces, so a rapid bg→fg cycle can't race a half-released camera.
  Future<void>? _pendingDispose;

  // Last observed window size, used by didChangeMetrics to detect PiP
  // entry/exit on Android OEM skins (Vivo, Xiaomi, OnePlus) that don't
  // reliably fire AppLifecycleState.paused/resumed for PiP transitions.
  Size? _lastWindowSize;

  Future<void> initProcess() async {
    await requestCameraPermission();
  }

  Future<void> _safeDispose(CameraController? ctrl) async {
    if (ctrl == null) return;
    try {
      await ctrl.dispose();
    } catch (e) {
      // CameraController.dispose() can throw PlatformException
      // (releaseFlutterSurfaceTexture) when the surface producer never
      // finished initializing. We log errorType so any other failure
      // mode (StateError, MissingPluginException) still shows up in
      // monitoring rather than being silently swallowed.
      MonitoringServiceHelper.logError(
        'Camera Dispose Failed',
        {
          'component': 'SelfieLogin',
          'error': e.toString(),
          'errorType': e.runtimeType.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      loginSelfieProvider =
          Provider.of<LoginSelfieProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      loginSelfie = loginSelfieProvider.selfie ?? LoginSelfie();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final ctrl = controller;
    controller = null;
    // Fire-and-forget — we can't await in dispose(). _safeDispose swallows
    // exceptions so a failed cleanup doesn't crash the navigation.
    _safeDispose(ctrl);
    super.dispose();
  }

  void _reinitializeCameraIfNeeded() async {
    // If camera permission is granted but camera is not initialized, reinitialize it
    if (camerastatus?.isGranted == true &&
        !_isCameraInitialized &&
        !loading &&
        !_initInFlight &&
        mounted) {
      setState(() {
        loading = true;
      });

      try {
        await getCameras();
        MonitoringServiceHelper.logInfo(
          'Camera Reinitialized After Background/PiP',
          {
            'component': 'SelfieLogin',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        MonitoringServiceHelper.logError(
          'Camera Reinitialization Failed',
          {
            'component': 'SelfieLogin',
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } finally {
        if (mounted) {
          setState(() {
            loading = false;
          });
        }
      }
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // PiP support: some Android OEM skins (notably Vivo FuntouchOS, MIUI,
    // OxygenOS) don't reliably fire AppLifecycleState.paused/resumed when
    // entering or exiting Picture-in-Picture. didChangeMetrics fires on
    // actual window size changes — rare enough to avoid the per-frame
    // thrash the previous addPostFrameCallback approach caused, broad
    // enough to catch PiP transitions the lifecycle callback missed.
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final view = views.first;
    final currentSize = view.physicalSize / view.devicePixelRatio;
    final previousSize = _lastWindowSize;
    _lastWindowSize = currentSize;

    switch (classifyPipTransition(previousSize, currentSize)) {
      case PipTransition.entered:
        // Dispose the camera proactively to release CameraX surfaces —
        // the user can't interact with the preview in PiP anyway.
        if (controller != null && controller!.value.isInitialized) {
          final ctrl = controller;
          controller = null;
          _pendingDispose = _safeDispose(ctrl);
          if (mounted) {
            setState(() {
              _isCameraInitialized = false;
            });
          }
          MonitoringServiceHelper.logInfo(
            'Camera Disposed On PiP Entry',
            {
              'component': 'SelfieLogin',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
        break;
      case PipTransition.exited:
        // Reinit if the camera was disposed during PiP. The existing
        // guards (mounted, !_initInFlight, !_isCameraInitialized, !loading)
        // keep this a no-op when nothing needs to be done.
        _reinitializeCameraIfNeeded();
        break;
      case PipTransition.none:
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dispose camera controller when app goes to background to prevent
    // CameraX plugin from trying to access display from non-visual context
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (controller != null && controller!.value.isInitialized) {
        final ctrl = controller;
        controller = null;
        // Track this so reinit can wait for it on resume.
        _pendingDispose = _safeDispose(ctrl);
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
      }
    } else if (state == AppLifecycleState.resumed && mounted) {
      // Reinitialize camera when returning to foreground
      if (_wentToSettings) {
        _wentToSettings = false;
        // Re-request permissions to update camerastatus
        setState(() {
          loading = true;
        });
        requestCameraPermission().then((_) {
          if (mounted) {
            setState(() {
              loading = false;
            });
          }
        });
      } else {
        // Delay slightly to ensure UI is fully visible
        Future.delayed(const Duration(milliseconds: 300), () {
          _reinitializeCameraIfNeeded();
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
          'component': 'SelfieForLogin',
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
      } else {
        // Regular denial for one or both
        setState(() {
          camerastatus = PermissionStatus.denied;
        });
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
    // Re-entrancy guard. Previously build() + lifecycle callbacks could
    // all spawn parallel getCameras() chains, each creating its own
    // CameraController; failed ones became orphaned (no reference to
    // dispose) and kept their 3 CameraX surfaces bound until process
    // death — blocking every subsequent init on strict devices.
    if (_initInFlight) {
      MonitoringServiceHelper.logInfo(
        'Camera Init Skipped - Already In Flight',
        {
          'component': 'SelfieLogin',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return;
    }
    _initInFlight = true;
    try {
      // Wait for any pending dispose from a recent lifecycle pause before
      // binding new camera surfaces — otherwise a rapid bg→fg cycle can
      // race the cleanup and hit "too many use cases".
      final pending = _pendingDispose;
      if (pending != null) {
        await pending;
        _pendingDispose = null;
      }

      cameras = await availableCameras();
      if (cameras.isEmpty) {
        MonitoringServiceHelper.logError(
          'No Cameras Available',
          {
            'component': 'SelfieLogin',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        if (mounted) setState(() {});
        return;
      }
      try {
        await onNewCameraSelected(
            widget.isForMarkArrival ? cameras[0] : cameras[1]);
      } catch (e) {
        MonitoringServiceHelper.logError(
          'Primary Camera Selection Failed',
          {
            'component': 'SelfieLogin',
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        try {
          await onNewCameraSelected(cameras[0]);
          MonitoringServiceHelper.logInfo(
            'Fallback Camera Selection Success',
            {
              'component': 'SelfieLogin',
              'selectedCamera': 'fallback',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        } catch (err) {
          MonitoringServiceHelper.logError(
            'Camera Initialization Failed',
            {
              'component': 'SelfieLogin',
              'error': err.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      }
      if (mounted) setState(() {});
    } finally {
      _initInFlight = false;
    }
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    // Dispose previous controller first and wait for cleanup
    if (previousCameraController != null) {
      await _safeDispose(previousCameraController);
      // Add delay to ensure hardware resources are fully released
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Clear reference before creating new controller
    if (mounted) {
      setState(() {
        controller = null;
        _isCameraInitialized = false;
      });
    }

    // Try initialization with decreasing resource requirements
    final resolutionFallbacks = [
      currentResolutionPreset,
      if (currentResolutionPreset != ResolutionPreset.medium)
        ResolutionPreset.medium,
      if (currentResolutionPreset != ResolutionPreset.low) ResolutionPreset.low,
    ];

    CameraController? newController;
    ResolutionPreset? successfulPreset;

    for (final preset in resolutionFallbacks) {
      try {
        newController = CameraController(
          cameraDescription,
          preset,
          imageFormatGroup: ImageFormatGroup.jpeg,
          enableAudio:
              false, // Disable audio - reduces surface count for low-end devices
        );

        await newController.initialize();

        // If the widget was disposed while initialize() was running,
        // dispose this controller and bail. Continuing would create an
        // orphaned controller (no reference to dispose later) holding
        // 3 CameraX surfaces.
        if (!mounted) {
          await _safeDispose(newController);
          return;
        }

        successfulPreset = preset;

        MonitoringServiceHelper.logInfo(
          'Camera Controller Initialized',
          {
            'component': 'SelfieLogin',
            'cameraDirection': cameraDescription.lensDirection.toString(),
            'resolution': preset.toString(),
            'usedFallback': preset != currentResolutionPreset,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        break; // Success - exit loop
      } on CameraException catch (e) {
        MonitoringServiceHelper.logError(
          'Camera Init Attempt Failed',
          {
            'component': 'SelfieLogin',
            'error': e.toString(),
            'cameraDirection': cameraDescription.lensDirection.toString(),
            'resolution': preset.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // Dispose failed controller before trying next preset. Must not
        // throw — if dispose crashes (e.g. releaseFlutterSurfaceTexture),
        // the failed bind's surfaces stay attached and every following
        // preset hits "too many use cases" on strict devices.
        await _safeDispose(newController);
        newController = null;

        // Small delay before retry
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // initialize() can throw types other than CameraException
        // (PlatformException, StateError). Don't retry on the unknown,
        // but dispose the failed controller so its surfaces don't leak,
        // then propagate so getCameras() can fall back to cameras[0].
        MonitoringServiceHelper.logError(
          'Camera Init Unexpected Error',
          {
            'component': 'SelfieLogin',
            'error': e.toString(),
            'errorType': e.runtimeType.toString(),
            'cameraDirection': cameraDescription.lensDirection.toString(),
            'resolution': preset.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        await _safeDispose(newController);
        newController = null;
        rethrow;
      }
    }

    if (newController == null || successfulPreset == null) {
      MonitoringServiceHelper.logError(
        'Camera Initialization Failed - All Presets Exhausted',
        {
          'component': 'SelfieLogin',
          'cameraDirection': cameraDescription.lensDirection.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      // Rethrow to trigger fallback camera in getCameras()
      throw CameraException('InitFailed', 'All resolution presets failed');
    }

    // Capture into a local non-null so a concurrent dispose() nulling
    // `controller` between the two setStates below can't crash us with
    // "Null check operator used on a null value".
    final CameraController boundController = newController;

    // If the widget unmounted during the await gaps inside the loop,
    // dispose the bound controller instead of leaking it. addListener
    // below would also throw "setState() called after dispose()" if
    // we let it run on an unmounted widget.
    if (!mounted) {
      await _safeDispose(boundController);
      return;
    }

    setState(() {
      controller = boundController;
      currentResolutionPreset = successfulPreset!;
    });

    boundController.addListener(() {
      if (mounted) setState(() {});
    });

    setState(() {
      _isCameraInitialized = boundController.value.isInitialized;
    });
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
        if (widget.isForMarkArrival) {
          loginSelfie.gatePhoto = file;
          loginSelfie.isForMarkArrival = true;
          buildingPhoto = file;

          await ClevertapSetup.logEvent(
              TrackingEvents.buildingGatePhotoClicked, {
            "action": "building gate photo clicked",
          });
        } else {
          loginSelfie.selfie = file;
          await ClevertapSetup.logEvent(TrackingEvents.selfieClicked, {
            "action": "selfie clicked",
          });
        }
        loginSelfieProvider.notifyLoginSelfieListeners();
      });
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SelfiePreview(
                    buildingGatePhoto: buildingPhoto,
                  )));
    } on CameraException catch (e) {
      print('Error occured while taking picture: $e');

      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size(double.infinity, 100.h),
        child: CommonAppBar(
          title: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: widget.isForMarkArrival ? 0 : 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 8.h,
                ),
                Text(
                  widget.isForMarkArrival
                      ? languageProvider.getMessage("photo_building_gate",
                          "Take a photo of the building gate")
                      : userProfileProvider.user?.alternateDeliveryMethod ==
                              AlternateDeliveryMethod.yulu
                          ? languageProvider.getMessage("take_selfie_bike",
                              "Take a selfie with your bike")
                          : languageProvider.getMessage(
                              "take_selfie", "Take a selfie"),
                  style: TextStyle(
                      color: const Color(0xFF101840),
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.isForMarkArrival
                      ? languageProvider.getMessage("main_gate_visible",
                          "Please make sure the main gate is properly visible")
                      : userProfileProvider.user?.alternateDeliveryMethod ==
                              AlternateDeliveryMethod.yulu
                          ? languageProvider.getMessage("helmet_visible",
                              "Please make sure to wear your helmet")
                          : languageProvider.getMessage("uniform_visible",
                              "Make sure your uniform is clearly visible"),
                  style: TextStyle(
                    color: const Color(0xFF101840),
                    fontSize: 11.sp,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      body: camerastatus?.isGranted == true
          ? _isCameraInitialized &&
                  controller != null &&
                  controller!.value.isInitialized
              ? Center(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        Flexible(
                          child: AspectRatio(
                            aspectRatio:
                                1.000 / (controller!.value.aspectRatio),
                            child: CameraPreview(controller!),
                          ),
                        ),
                        SizedBox(
                          height: 130.h,
                          child: Center(
                            child: GestureDetector(
                              onTap: () async {
                                await takePicture(context);
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    height: 82.h,
                                    width: 82.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 70.h,
                                    width: 70.w,
                                    padding: EdgeInsets.all(8.r),
                                    decoration: const BoxDecoration(
                                        color: AppColors.brand,
                                        shape: BoxShape.circle),
                                    child: Center(
                                        child: Text(
                                      languageProvider.getMessage(
                                          "click", 'Click'),
                                      style: TextStyle(
                                          color: AppColors.n0,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600),
                                    )),
                                  )
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              : Center(
                  child: loading
                      ? const CupertinoActivityIndicator()
                      : const Text('Camera initialization failed.'),
                )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.all(24.r),
                    child: Text(
                      "Please grant camera permissions!",
                      style: TextStyle(fontSize: 17.sp),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        // backgroundColor: AppColors.brand,
                        onPressed: () async {
                          if (camerastatus?.isPermanentlyDenied == true) {
                            _wentToSettings = true;
                            await openAppSettings();
                          } else {
                            await requestCameraPermission();
                          }
                        },
                        child: const Text(
                          "Grant Camera & Microphone Permissions!",
                          style: TextStyle(color: AppColors.n0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

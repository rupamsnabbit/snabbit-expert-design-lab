import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../providers/current_picture_provider.dart';

enum CameraStatus {
  notInitialized,
  noPermission,
  initializing,
  ready,
  takingPicture,
  error,
}

class PictureCapture extends StatefulWidget {
  final Function(File image)? onImageCaptured;

  const PictureCapture({
    super.key,
    this.onImageCaptured,
  });

  @override
  State<PictureCapture> createState() => _PictureCaptureState();
}

class _PictureCaptureState extends State<PictureCapture>
    with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  CameraStatus cameraStatus = CameraStatus.notInitialized;
  int selectedCameraIndex = 1;
  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;
  bool _wentToSettings = false;
  late CurrentPictureProvider pictureProvider;
  late LanguageProvider languageProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    pictureProvider =
        Provider.of<CurrentPictureProvider>(context, listen: false);
    Future(() {
      pictureProvider.clearCurrentPicture();
    });
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final ctrl = controller;
    controller = null;
    ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Dispose camera when app goes to background/PiP
      if (controller != null && controller!.value.isInitialized) {
        final ctrl = controller;
        controller = null;
        ctrl?.dispose();
        if (mounted) {
          setState(() {
            cameraStatus = CameraStatus.notInitialized;
          });
        }
      }
    } else if (state == AppLifecycleState.resumed && mounted) {
      // Reinitialize when app comes back to foreground
      if (_wentToSettings) {
        _wentToSettings = false;
        // Re-request permissions when returning from settings
        _initializeCamera();
      } else {
        // Delay slightly to ensure UI is fully visible
        Future.delayed(const Duration(milliseconds: 300), () {
          _reinitializeCameraIfNeeded();
        });
      }
    }
  }

  void _reinitializeCameraIfNeeded() async {
    // If camera is not initialized and we're not already initializing, reinitialize it
    if (cameraStatus == CameraStatus.notInitialized && mounted) {
      try {
        await _initializeCamera();
        MonitoringServiceHelper.logInfo(
          'Camera Reinitialized After Background/PiP',
          {
            'component': 'PictureCapture',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        MonitoringServiceHelper.logError(
          'Camera Reinitialization Failed',
          {
            'component': 'PictureCapture',
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      cameraStatus = CameraStatus.initializing;
    });

    MonitoringServiceHelper.logDebug(
      'Camera Initialization Started',
      {
        'previousStatus': cameraStatus.toString(),
        'newStatus': CameraStatus.initializing.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    try {
      // Check camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          cameraStatus = CameraStatus.noPermission;
        });

        MonitoringServiceHelper.logWarning(
          'Camera Permission Denied',
          {
            'permissionStatus': status.toString(),
            'newCameraStatus': CameraStatus.noPermission.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        return;
      }

      // Get available cameras
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          cameraStatus = CameraStatus.error;
        });

        MonitoringServiceHelper.logError(
          'No Cameras Available',
          {
            'camerasCount': 0,
            'newCameraStatus': CameraStatus.error.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        return;
      }

      // Select front camera by default for selfies
      // if (widget.frontCameraOnly) {
      //   final frontCameras = cameras
      //       .where(
      //           (camera) => camera.lensDirection == CameraLensDirection.front)
      //       .toList();
      //   if (frontCameras.isNotEmpty) {
      //     selectedCameraIndex = cameras.indexOf(frontCameras.first);
      //   }
      // }

      // Initialize the controller
      await _setupCamera(selectedCameraIndex);
    } catch (e) {
      setState(() {
        cameraStatus = CameraStatus.error;
      });

      MonitoringServiceHelper.logError(
        'Camera Initialization Failed',
        {
          'error': e.toString(),
          'newCameraStatus': CameraStatus.error.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Future<void> _setupCamera(int index) async {
    if (cameras.isEmpty) return;

    // Dispose previous controller if exists and wait for cleanup
    if (controller != null) {
      final previousController = controller;
      controller = null;
      await previousController?.dispose();
      // Add delay to ensure hardware resources are fully released
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Ensure valid camera index
    int cameraIndex = cameras.length > index ? index : 0;
    final cameraDescription = cameras[cameraIndex];

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
          enableAudio: false, // Disable audio - reduces surface count for low-end devices
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await newController.initialize();
        successfulPreset = preset;

        MonitoringServiceHelper.logInfo(
          'Camera Controller Initialized',
          {
            'component': 'PictureCapture',
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
            'component': 'PictureCapture',
            'error': e.toString(),
            'cameraDirection': cameraDescription.lensDirection.toString(),
            'resolution': preset.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // Dispose failed controller before trying next preset
        await newController?.dispose();
        newController = null;

        // Small delay before retry
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    if (newController == null || successfulPreset == null) {
      MonitoringServiceHelper.logError(
        'Camera Initialization Failed - All Presets Exhausted',
        {
          'component': 'PictureCapture',
          'cameraDirection': cameraDescription.lensDirection.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      setState(() {
        cameraStatus = CameraStatus.error;
      });
      return;
    }

    // Replace with the new controller
    if (mounted) {
      setState(() {
        controller = newController;
        currentResolutionPreset = successfulPreset!;
        cameraStatus = CameraStatus.ready;
      });
    }
  }

  Future<void> _takePicture() async {
    if (controller == null || !controller!.value.isInitialized) {
      MonitoringServiceHelper.logError(
        'Picture Capture Failed',
        {
          'error': 'Camera controller not initialized',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return;
    }

    try {
      setState(() {
        cameraStatus = CameraStatus.takingPicture;
      });

      MonitoringServiceHelper.logDebug(
        'Picture Capture Started',
        {
          'cameraDirection': controller!.description.lensDirection.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Take picture
      final XFile image = await controller!.takePicture();
      final File imageFile = File(image.path);

      // Fix the mirroring for front camera
      final isFrontCamera =
          controller!.description.lensDirection == CameraLensDirection.front;
      File processedImage = imageFile;

      if (isFrontCamera) {
        // Create a correctly flipped image
        processedImage = await _flipImage(imageFile);
      }

      // Store in provider
      pictureProvider.setCurrentPicture(processedImage);

      MonitoringServiceHelper.logInfo(
        'Picture Capture Successful',
        {
          'imagePath': processedImage.path,
          'imageSize': await processedImage.length(),
          'wasFlipped': isFrontCamera,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Call callback if provided
      if (widget.onImageCaptured != null) {
        widget.onImageCaptured!(processedImage);
      }

      setState(() {
        cameraStatus = CameraStatus.ready;
      });
    } catch (e) {
      setState(() {
        cameraStatus = CameraStatus.error;
      });

      MonitoringServiceHelper.logError(
        'Picture Capture Failed',
        {
          'error': e.toString(),
          'newCameraStatus': CameraStatus.error.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        showSnackbar(
          context,
          'Failed to capture image: ${e.toString()}',
        );
      }
    }
  }

  // Helper method to flip image horizontally
  Future<File> _flipImage(File inputImage) async {
    // Read the image using the image package
    final bytes = await inputImage.readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) return inputImage;

    // Flip the image horizontally
    final flippedImage = img.flipHorizontal(originalImage);

    // Save the flipped image to a temporary file
    final directory = await getTemporaryDirectory();
    final outputPath =
        '${directory.path}/flipped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputFile = File(outputPath);

    await outputFile.writeAsBytes(img.encodeJpg(flippedImage));

    return outputFile;
  }

  // void _switchCamera() async {
  //   if (!widget.frontCameraOnly && cameras.length > 1) {
  //     selectedCameraIndex = (selectedCameraIndex + 1) % cameras.length;
  //     await _setupCamera(selectedCameraIndex);
  //   }
  // }

  Widget _buildCameraContent() {
    switch (cameraStatus) {
      case CameraStatus.notInitialized:
      case CameraStatus.initializing:
        return const Center(
          child: CupertinoActivityIndicator(),
        );
      case CameraStatus.noPermission:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Camera permission denied',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.n80,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () async {
                  _wentToSettings = true;
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      case CameraStatus.ready:
        // Check if controller is valid and initialized before using it
        if (controller == null || !controller!.value.isInitialized) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }

        // Check if we're using the front camera to determine if we need to flip the preview
        final isFrontCamera =
            controller!.description.lensDirection == CameraLensDirection.front;

        return Column(
          children: [
            // Camera preview with proper orientation
            Expanded(
              child: Container(
                width: 1.sw,
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                // Apply a transform if needed to fix the mirroring/inversion
                child: pictureProvider.currentPicture != null
                    ? Image.file(
                        pictureProvider.currentPicture!,
                        fit: BoxFit.cover,
                      )
                    : Transform.scale(
                        // For camera preview, flip horizontally if front camera
                        scaleX: isFrontCamera ? -1.0 : 1.0,
                        child: CameraPreview(controller!),
                      ),
              ),
            ),
            // Capture button
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 82.r,
                  height: 82.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.p20,
                    ),
                  ),
                  padding: EdgeInsets.all(6.r),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brand,
                    ),
                    child: Text(
                      languageProvider.getMessage(
                        'click',
                        'Click',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.n0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case CameraStatus.takingPicture:
        return const Center(
          child: CupertinoActivityIndicator(),
        );
      case CameraStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Camera initialization failed',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.n80,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if camera needs reinitialization on every build
    // This handles cases where PiP mode or background doesn't trigger lifecycle callbacks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reinitializeCameraIfNeeded();
    });

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: _buildCameraContent(),
    );
  }
}

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:location/location.dart' hide PermissionStatus;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/services/analytics/onboarding_analytics.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:geolocator/geolocator.dart';

class PermissionPopupProvider with ChangeNotifier {
  bool _locationService = false;
  bool _locationPermissionBottom = false;
  bool _locationPermissionAlert = false;

  bool get locationService => _locationService;

  bool get locationPermissionBottom => _locationPermissionBottom;

  bool get locationPermissionAlert => _locationPermissionAlert;

  set locationService(bool value) {
    _locationService = value;
    notifyListeners();
  }

  set locationPermissionBottom(bool value) {
    _locationPermissionBottom = value;
    notifyListeners();
  }

  set locationPermissionAlert(bool value) {
    _locationPermissionAlert = value;
    notifyListeners();
  }
}

// Helper methods to avoid code duplication
Future<bool> isLocationDeniedForever() async {
  try {
    final locationStatus = await Permission.location.status;
    final locationAlwaysStatus = await Permission.locationAlways.status;
    return locationStatus.isPermanentlyDenied ||
        locationAlwaysStatus.isPermanentlyDenied;
  } catch (e) {
    return true;
  }
}

Future<bool> isLocationAlwaysNotGranted() async {
  try {
    final locationAlwaysStatus = await Permission.locationAlways.status;
    return !locationAlwaysStatus.isGranted;
  } catch (e) {
    MonitoringServiceHelper.logCriticalError(
      'isLocationAlwaysNotGranted Check Failed',
      {
        'component': 'LocationPermissionConfirmation',
        'error': e.toString(),
      },
    );
    return true;
  }
}

Future<bool> isLocationServiceEnabled() async {
  try {
    return await Geolocator.isLocationServiceEnabled();
  } catch (e) {
    return true;
  }
}

Future<bool> isPreciseLocationEnabled() async{
  try {
    LocationAccuracyStatus status = await Geolocator.getLocationAccuracy();
    return status == LocationAccuracyStatus.precise;
  } catch (e) {
    return true;
  }
}

void showLocationPermissionConfirmation() {
  try {
    final provider = Provider.of<PermissionPopupProvider>(
        GlobalState().navigatorKey.currentContext!,
        listen: false);
    isLocationServiceEnabled().then((val) {
      if (val == true) {
        isLocationAlwaysNotGranted().then((notGranted) {
          if (notGranted) {
            MonitoringServiceHelper.logInfo(
              'Location Permission Dialog Shown',
              {
                'component': 'LocationPermissionConfirmation',
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
            try {
              if (provider.locationPermissionBottom == false &&
                  provider.locationPermissionAlert == false) {
                provider.locationPermissionBottom = true;
                showModalBottomSheet(
                  isDismissible: false,
                  enableDrag: false,
                  context: GlobalState().navigatorKey.currentContext!,
                  builder: (BuildContext context) {
                    return const LocationPermissionConfirmation();
                  },
                );
              }
            } catch (e) {
              MonitoringServiceHelper.logCriticalError(
                'Location Permission Dialog Failed to Show Global context - ${GlobalState()
                    .navigatorKey.currentContext}. And error is - $e',
                {
                  'component': 'LocationPermissionConfirmation',
                  'timestamp': DateTime.now().toIso8601String(),
                },
              );
            }
          } else {
            isPreciseLocationEnabled().then((enabled){
              if(!enabled){
                showCompulsoryPermissionDialog();
              }
            });
          }
        });
      } else {
        ClevertapSetup.logEvent(TrackingEvents.locationServiceOff, {});
        Location locationController = Location();
        if (provider.locationService == false) {
          provider.locationService = true;
          locationController.requestService().then((allowed) {
            provider.locationService = false;
            showLocationPermissionConfirmation();
          });
        }
      }
    });
  } catch(e) {
    // DO NOTHING
  }
}

class LocationPermissionConfirmation extends StatefulWidget {
  const LocationPermissionConfirmation({super.key});

  @override
  State<LocationPermissionConfirmation> createState() =>
      _LocationPermissionConfirmationState();
}

class _LocationPermissionConfirmationState
    extends State<LocationPermissionConfirmation> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: CommonBottomSheetSetup(
        child: Column(
          children: [
            SizedBox(height: 16.h),
            const Text(
              "Snabbit Expert requires permission to access your location in background for your safety. Do you want to continue?",
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      MonitoringServiceHelper.logWarning(
                        'Location Permission Rejected',
                        {
                          'component': 'LocationPermissionConfirmation',
                          'action': 'user_rejected',
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );
                      PermissionPopupProvider? provider;
                      try {
                        provider = Provider.of<PermissionPopupProvider>(
                            GlobalState().navigatorKey.currentContext!,
                            listen: false);
                      } catch (e) {
                        // DO NOTHING
                      }
                      provider?.locationPermissionBottom = false;

                      Navigator.of(context).pop();
                      Future.delayed(const Duration(milliseconds: 250))
                          .then((_) {
                        showCompulsoryPermissionDialog();
                      });
                    },
                    child: const Text("No"),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await MonitoringServiceHelper.logInfo(
                        'Location Permission Request Started',
                        {
                          'component': 'LocationPermissionConfirmation',
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );
                      PermissionPopupProvider? provider;
                      try {
                        provider = Provider.of<PermissionPopupProvider>(
                            GlobalState().navigatorKey.currentContext!,
                            listen: false);
                      } catch (e) {
                        // DO NOTHING
                      }

                      if (await isLocationAlwaysNotGranted()) {
                        final prevDenied = await isLocationDeniedForever();
                        OnboardingAnalytics.logEvent(
                            TrackingEvents.locationPermissionPromptShown, {
                          'previously_denied': prevDenied ? 1 : 0,
                        });
                        final locationStatus =
                            await Permission.location.request();
                        bool isGranted = locationStatus.isGranted;
                        OnboardingAnalytics.logEvent(
                            TrackingEvents.locationPermissionResponse, {
                          'response':
                              _mapPermissionResponse(locationStatus),
                        });
                        if (isGranted == true) {
                          // Fire-and-forget: Geolocator.getCurrentPosition
                          // can take up to 10s (the timeout). Awaiting it
                          // would stall the locationAlways permission prompt
                          // — analytics must never gate the next UX step.
                          unawaited(_captureAndLogLocation());
                          final alwaysPermission =
                          await Permission.locationAlways.request();
                          isGranted = alwaysPermission.isGranted;
                          provider?.locationPermissionBottom = false;
                          if (isGranted != true) {
                            ClevertapSetup.logEvent(
                                TrackingEvents.locationAlwaysDenied, {});
                            MonitoringServiceHelper.logInfo(
                              'Always Location Permission Request Denied',
                              {
                                'component': 'LocationPermissionConfirmation',
                                'timestamp': DateTime.now().toIso8601String(),
                              },
                            );
                            showCompulsoryPermissionDialog();
                          }
                        } else {
                          provider?.locationPermissionBottom = false;
                          ClevertapSetup.logEvent(
                              TrackingEvents.locationPermissionDenied, {});
                          MonitoringServiceHelper.logInfo(
                            'Location Permission Request Denied',
                            {
                              'component': 'LocationPermissionConfirmation',
                              'timestamp': DateTime.now().toIso8601String(),
                            },
                          );
                          showCompulsoryPermissionDialog();
                        }
                      } else {
                        provider?.locationPermissionBottom = false;
                      }

                      await MonitoringServiceHelper.logInfo(
                        'Location Permission Request Completed',
                        {
                          'component': 'LocationPermissionConfirmation',
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );
                    },
                    child: const Text("Yes"),
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
}

void showCompulsoryPermissionDialog() {
  try {
    PermissionPopupProvider? provider;
    try {
      provider = Provider.of<PermissionPopupProvider>(
          GlobalState().navigatorKey.currentContext!,
          listen: false);
    } catch (e) {
      // DO NOTHING
    }
    if (provider?.locationPermissionAlert == false) {
      provider?.locationPermissionAlert = true;
      showDialog(
        barrierDismissible: false,
        context: GlobalState().navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return const CompulsoryLocationPermissionDialog();
        },
      ).then((_) {
        provider?.locationPermissionAlert = false;
      });
    }
  } catch (e) {
    // DO NOTHING
  }
}

class CompulsoryLocationPermissionDialog extends StatefulWidget {
  const CompulsoryLocationPermissionDialog({super.key});

  @override
  State<CompulsoryLocationPermissionDialog> createState() =>
      _CompulsoryLocationPermissionDialogState();
}

class _CompulsoryLocationPermissionDialogState
    extends State<CompulsoryLocationPermissionDialog>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool loading = true;
  bool isDeniedForever = false;
  bool notAlways = false;
  bool preciseLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndHandlePermissions().then((_) {
      loading = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndHandlePermissions();
    }
  }

  Future<void> _checkAndHandlePermissions() async {
    if (_checking) return;
    _checking = true;
    try {
      isDeniedForever = await isLocationDeniedForever();
      notAlways = await isLocationAlwaysNotGranted();
      preciseLocation = await isPreciseLocationEnabled();

      if (!isDeniedForever && !notAlways && preciseLocation) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      // else: keep dialog open
      if (mounted) {
        setState(() {});
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: !loading
            ? const Text("Allow location permission")
            : const SizedBox(),
        content: !loading
            ? Text(
            !preciseLocation?"\n\nTo allow precise location access, Go to Permissions > Location > Turn on Precise Location" : "Snabbit Expert requires location permission for flawless app execution. ${isDeniedForever ? "\n\nTo allow location access, Go to Permissions > Location > Allow all the time" : ""}")
            : const CupertinoActivityIndicator(),
        actions: <Widget>[
          if (!loading)
            SizedBox(
              width: 1.sw,
              child: ElevatedButton(
                onPressed: () async {
                  final deniedForever = await isLocationDeniedForever();
                  final notAlways = await isLocationAlwaysNotGranted();
                  final preciseLocation = await isPreciseLocationEnabled();
                  if (deniedForever) {
                    await openAppSettings();
                  } else if (notAlways) {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      showLocationPermissionConfirmation();
                    }
                  } else if (!preciseLocation){
                    if(context.mounted){
                      Navigator.pop(context);
                     openAppSettings();
                    }
                  }
                },
                child: Text(isDeniedForever ? "Settings" : "Allow"),
              ),
            ),
        ],
      ),
    );
  }
}

String _mapPermissionResponse(PermissionStatus status) {
  if (status.isGranted) return 'allow';
  if (status.isPermanentlyDenied) return 'deny';
  return 'dismiss';
}

Future<void> _captureAndLogLocation() async {
  try {
    final pos = await Geolocator.getCurrentPosition()
        .timeout(const Duration(seconds: 10));
    OnboardingAnalytics.logEvent(TrackingEvents.locationDetected, {
      'gps_lat': (pos.latitude * 100).round() / 100,
      'gps_long': (pos.longitude * 100).round() / 100,
    });
  } catch (_) {
    // Analytics must never crash the app
  }
}

/// Logs the initial location permission and service status at app start.
/// Call once from main() before showing any location permission UI.
Future<void> logInitialLocationPermissionStatus() async {
  try {
    final locationStatus = await Permission.location.status;
    final locationAlwaysStatus = await Permission.locationAlways.status;
    bool locationServiceEnabled = false;
    String locationAccuracy = 'unknown';
    try {
      locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      final accuracy = await Geolocator.getLocationAccuracy();
      locationAccuracy = accuracy.toString();
    } catch (_) {}
    await MonitoringServiceHelper.logInfo(
      'app_start_location_permission_status',
      {
        'component': 'AppStart',
        'location_status': locationStatus.name,
        'location_always_status': locationAlwaysStatus.name,
        'location_service_enabled': locationServiceEnabled,
        'location_accuracy': locationAccuracy,
      },
    );
  } catch (e) {
    await MonitoringServiceHelper.logCriticalError(
      'app_start_location_permission_status_failed',
      {
        'component': 'AppStart',
        'error': e.toString(),
      },
    );
  }
}

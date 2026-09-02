import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/providers/selfie_provider.dart';
import 'package:snabbit_runner/services/file_ops.dart';
import 'package:snabbit_runner/services/iot/collectors/location_collector.dart';
import 'package:snabbit_runner/services/iot/foreground_fallback/iot_foreground_fallback.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/enums.dart';
import '../utils/common_methods.dart';
import 'globals.dart';
import 'http_service.dart';

class RunnerHttp {
  // static Future<Response?> runnerBasic(
  //     {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
  //   try {
  //     final response = await HttpService().post(
  //         GlobalState().serverPath("api/v1/runners/basic"),
  //         headers: headers ?? {},
  //         data: data ?? {});
  //     // if (response.statusCode == 200) {
  //     return response;
  //     // } else {
  //     //   return response;
  //     // }
  //   } catch (e) {
  //     // debugPrint(e.toString());
  //     return null;
  //   }
  // }

  static Future<Response?> runnersMe({Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().get(
          GlobalState().serverPath("api/v1/runners/me"),
          headers: headers ?? {});
      return response;
    } catch (e, st) {
      // Don't swallow silently: this response now gates the login-time cohort
      // decision (mqtt_config → KMP stack vs Flutter PartnerHome), so a failed
      // fetch must be visible. Still returns null — callers treat null/non-200
      // as the safe default (polling cohort / existing error path).
      MonitoringServiceHelper.logError('runnersMe request failed', {
        'error': e.toString(),
        'stack': st.toString(),
      });
      return null;
    }
  }

  static Future<Response?> runnerReferral(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/runners/me/have_referral"),
          headers: headers ?? {},
          data: data);
      return response;
    } catch (e) {
      return null;
    }
  }

  /// GET active services for registration (JSON array of id, name, image_url, tag).
  static Future<Response?> getServicesList(
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().get(
          GlobalState().serverPath("api/v1/runners/me/active_services"),
          headers: headers ?? {});
      return response;
    } catch (e) {
      return null;
    }
  }

  /// GET period leave balance (max, taken, available).
  static Future<Response?> periodLeaveAvailability(
      {Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().get(
          GlobalState()
              .serverPath("api/v1/runners/me/period_leave/availability"),
          headers: headers ?? {});
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnerRegistration(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final Response response = await HttpService().put(
        GlobalState().serverPath("api/v1/runners/me/registration"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> editDetailsReviewAction(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final Response response = await HttpService().post(
        GlobalState().serverPath("api/v1/runners/me/edit_registration_form"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnerRegistrationPreviousStep(
      {Map<String, dynamic>? headers, Map<String, dynamic>? data}) async {
    try {
      final Response response = await HttpService().put(
        GlobalState()
            .serverPath("api/v1/runners/me/previous_registration_step"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> resetRegistration({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final Response response = await HttpService().post(
        GlobalState().serverPath("api/v1/runners/me/reset_registration"),
        headers: headers ?? {},
        data: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Maps a GPS acquisition failure to a stable step name. Distinguishes
  /// "service disabled at fix time" (thrown by getCurrentPosition even when
  /// isLocationServiceEnabled() was true — typical of battery-saving location
  /// mode) and permission failures from a generic failure, without parsing
  /// platform error strings.
  static String _classifyGpsFailureStep(Object e) {
    if (e is TimeoutException) return 'gps_timeout';
    if (e is LocationServiceDisabledException) return 'gps_service_disabled';
    if (e is PermissionDeniedException) return 'gps_permission_denied';
    if (e is PermissionDefinitionsNotFoundException) {
      return 'gps_permission_definitions_missing';
    }
    if (e is PositionUpdateException) return 'gps_position_update_failed';
    return 'gps_failed';
  }

  static Future<Response?> runnerAppCurrentState(
      {Map<String, dynamic>? headers,
      bool isFg = true,
      bool skipIotWithRunnerState = false}) async {
    if (GlobalState().effectiveDebugStubRunnerAppCurrentState) {
      return Response(
        requestOptions:
            RequestOptions(path: 'debug_stub:runner_app_current_state'),
        statusCode: 200,
        data: Map<String, dynamic>.from(
          GlobalState().debugStubRunnerAppCurrentStateBody!,
        ),
      );
    }

    String? batteryLevel;
    bool? serviceEnabled;
    LocationPermission? permission;
    // Nullable so we can pass it (or null on cache-hit / GPS-failure paths)
    // to the foreground IoT fallback hook below the if-skipIotWithRunnerState
    // block. Was previously non-nullable + uninitialized.
    Position? capturedPosition;
    double? latitude;
    double? longitude;

    // Skip location/battery fetch when IoT is handling it (recurring background calls)
    if (!skipIotWithRunnerState) {
      try {
        batteryLevel = await getBatteryLevel();
        // Option B: try cached location from IoT DB first to avoid blocking on GPS
        try {
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getString('user_id');
          if (userId != null && userId.isNotEmpty) {
            final cached = await LocationCollector()
                .getLastCollected(userId, maxAgeSeconds: 60);
            if (cached != null) {
              latitude = cached.lat;
              longitude = cached.long;
              try {
                await MonitoringServiceHelper.logInfo(
                  'location_sync_status',
                  {'reason': 'location_from_cache', 'is_fg': isFg},
                );
              } catch (_) {}
            }
          }
        } catch (_) {}

        if (latitude == null || longitude == null) {
          serviceEnabled = await Geolocator.isLocationServiceEnabled();

          if (serviceEnabled) {
            permission = await Geolocator.checkPermission();

            if ([LocationPermission.always, LocationPermission.whileInUse]
                .contains(permission)) {
              const defaultGpsTimeout = 30;
              final gpsTimeoutSeconds = RemoteConfigService.instance.getInt(
                  'expert_current_state_gps_timeout_secs',
                  defaultValue: defaultGpsTimeout);
              final effectiveGpsTimeout =
                  gpsTimeoutSeconds > 0 ? gpsTimeoutSeconds : defaultGpsTimeout;
              try {
                MonitoringServiceHelper.logInfo('expert_state_sync', {
                  'step': 'gps_start',
                  'timeout_secs': effectiveGpsTimeout,
                  'is_fg': isFg,
                  'permission': permission.name
                });
              } catch (_) {}
              final gpsStartMs = DateTime.now().millisecondsSinceEpoch;
              capturedPosition = await Geolocator.getCurrentPosition(
                locationSettings: LocationSettings(
                  accuracy: LocationAccuracy.bestForNavigation,
                  timeLimit: Duration(seconds: effectiveGpsTimeout),
                ),
              );
              latitude = capturedPosition.latitude;
              longitude = capturedPosition.longitude;
              try {
                MonitoringServiceHelper.logInfo('expert_state_sync', {
                  'step': 'gps_success',
                  'duration_ms':
                      DateTime.now().millisecondsSinceEpoch - gpsStartMs,
                  'accuracy': capturedPosition.accuracy,
                  'is_fg': isFg,
                  'permission': permission.name
                });
              } catch (_) {}
            } else {
              try {
                await MonitoringServiceHelper.logWarning(
                  'location_sync_status',
                  {
                    'reason':
                        LocationSyncFailureReason.locationPermissionMissing.key,
                    'is_fg': isFg,
                    'skip_iot_with_runner_state': skipIotWithRunnerState,
                    'location_permission': permission.name,
                  },
                );
              } catch (_) {}
            }
          } else {
            try {
              await MonitoringServiceHelper.logWarning(
                'location_sync_status',
                {
                  'reason':
                      LocationSyncFailureReason.locationServiceDisabled.key,
                  'is_fg': isFg,
                  'skip_iot_with_runner_state': skipIotWithRunnerState,
                },
              );
            } catch (_) {}
          }
        }
      } catch (e) {
        /// Any code written in this catch block should be wrapped in try-catch and its catch should NOT return NULL
        final gpsStep = _classifyGpsFailureStep(e);
        try {
          MonitoringServiceHelper.logError('expert_state_sync',
              {'step': gpsStep, 'error': e.toString(), 'is_fg': isFg});
        } catch (_) {}
        try {
          await MonitoringServiceHelper.logError(
            'location_sync_status',
            {
              'reason': LocationSyncFailureReason.locationStepFailed.key,
              'is_fg': isFg,
              'skip_iot_with_runner_state': skipIotWithRunnerState,
              'error': e.toString(),
            },
          );
        } catch (_) {}
      }
    }

    // IoT foreground fallback: if the bg service is dead and IoT data is
    // going stale, piggyback on this poll's GPS fix to send a make-up ping
    // to atlas-iot. All gating lives in IotForegroundFallback; this call is
    // fire-and-forget so it never delays current_state's own HTTP below.
    // See: project_iot_drift_rootcause memory for context. Do not remove
    // without understanding the drift coverage (~66% of patched-cohort
    // drift windows) it provides.
    //
    // Gated on isFg: runnerAppCurrentState also runs in the FCM and
    // flutter_background_service isolates (isFg:false), where the fallback
    // would only no-op at its own foreground gate — skip the wasted object
    // construction + config read there entirely.
    if (isFg) {
      try {
        final fbPrefs = await SharedPreferences.getInstance();
        final fbUserId = fbPrefs.getString('user_id');
        if (fbUserId != null && fbUserId.isNotEmpty) {
          unawaited(
              IotForegroundFallback().maybeSend(capturedPosition, fbUserId));
        }
      } catch (e) {
        // Best-effort: a prefs failure here means the fallback can't fire, but
        // it must never affect current_state. Log so "why isn't the fallback
        // firing?" is distinguishable from "disabled by config".
        debugPrint('[IoT Fg Fallback] hook skipped, prefs read failed: $e');
      }
    }

    final httpStartMs = DateTime.now().millisecondsSinceEpoch;
    try {
      const defaultHttpTimeout = 30;
      final httpTimeoutRaw = RemoteConfigService.instance.getInt(
          'current_state_http_timeout_seconds',
          defaultValue: defaultHttpTimeout);
      final effectiveHttpTimeout =
          httpTimeoutRaw > 0 ? httpTimeoutRaw : defaultHttpTimeout;
      try {
        MonitoringServiceHelper.logInfo('expert_state_sync', {
          'step': 'http_start',
          'timeout_secs': effectiveHttpTimeout,
          'is_fg': isFg
        });
      } catch (_) {}
      final response = await HttpService()
          .get(
              GlobalState().serverPath(
                  "api/v1/runners/me/app/current_state?lat=$latitude&lng=$longitude&battery=$batteryLevel&is_fg=$isFg"),
              headers: headers ?? {})
          .timeout(Duration(seconds: effectiveHttpTimeout), onTimeout: () {
        throw TimeoutException('Request timed out');
      });
      try {
        MonitoringServiceHelper.logInfo('expert_state_sync', {
          'step': 'http_complete',
          'status_code': response.statusCode,
          'duration_ms': DateTime.now().millisecondsSinceEpoch - httpStartMs,
          'is_fg': isFg
        });
      } catch (_) {}
      playSoundOnReceivingNewJob(response, isFg: isFg);
      return response;
    } catch (e) {
      try {
        MonitoringServiceHelper.logError('expert_state_sync', {
          'step': 'http_error',
          'error': e.runtimeType.toString(),
          'duration_ms': DateTime.now().millisecondsSinceEpoch - httpStartMs,
          'is_fg': isFg
        });
      } catch (_) {}
      // Classify failure reason
      String reason = LocationSyncFailureReason.unknown.key;
      if (e is TimeoutException) {
        reason = LocationSyncFailureReason.timeout.key;
      } else if (e is DioException) {
        reason = "${LocationSyncFailureReason.dioException.key}_${e.type}";
      }

      try {
        await MonitoringServiceHelper.logError(
          'location_sync_status',
          {
            'is_fg': isFg,
            'skip_iot_with_runner_state': skipIotWithRunnerState,
            'reason': reason,
            'error': e.toString(),
          },
        );
      } catch (_) {}

      if (isFg) {
        await FileStorage.writeState('stopped');
      }
      return null;
    }
  }

  static Future<Response?> runnerDocuments({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    int? runnerId,
  }) async {
    try {
      final response = await HttpService().get(
          GlobalState().serverPath("api/v1/runners/$runnerId/documents"),
          queryParameters: queryParameters ?? {},
          headers: headers ?? {});
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnersMeHelpline({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    int? runnerId,
  }) async {
    try {
      final response = await HttpService().get(
          GlobalState().serverPath("api/v1/runners/me/helpline"),
          queryParameters: queryParameters ?? {},
          headers: headers ?? {});
      return response;
    } catch (e) {
      return null;
    }
  }

  /// GET `api/v1/jobs/task_collection?job_id=...`
  static Future<Response?> runnerHouseTasks({
    required int jobId,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final qp = <String, dynamic>{
        ...?queryParameters,
        'job_id': jobId,
      };
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/jobs/task_collection"),
        queryParameters: qp,
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnerSubmitHouseTasks({
    required int jobId,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/jobs/$jobId/update_task_collection"),
        data: data ?? {},
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnerAddReferral({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/runner_referrals"),
        data: data ?? {},
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnerAddMultipleReferrals({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState()
            .serverPath("api/v1/runner_referrals/create_multiple_referrals"),
        data: data ?? {},
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnerReferrals({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runner_referrals/me"),
        queryParameters: queryParameters ?? {},
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Resend registration code to runner
  /// Sends code via SMS and WhatsApp
  static Future<Response?> resendRegistrationCode({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/runners/me/er_code"),
        headers: headers ?? {},
        data: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnerReferralsDetails({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runner_referrals/me/details"),
        queryParameters: queryParameters ?? {},
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnerCustomerRating({
    int? jobId,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();

      if (position != null) {
        data ??= {};
        data.addAll({
          'location': {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/jobs/$jobId/update_customer_rating"),
        data: data ?? {},
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> runnerSOS({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/runners/me/sos"),
        data: data ?? {},
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      MonitoringServiceHelper.logError(
        'RunnerHttp: runnerSOS failed',
        {'error': e.toString(), 'data': data},
      );
      return null;
    }
  }

  static Future<Response?> runnerSOSInitiate({
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/runners/me/sos/initiate"),
        data: data ?? {},
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      MonitoringServiceHelper.logError(
        'RunnerHttp: runnerSOSInitiate failed',
        {'error': e.toString(), 'data': data},
      );
      return null;
    }
  }

  static Future<Response?> runnerSOSActive({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/me/sos/active"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      MonitoringServiceHelper.logError(
        'RunnerHttp: runnerSOSActive failed',
        {'error': e.toString()},
      );
      return null;
    }
  }

  static Future<Response?> uploadContactsFile(String filePath) async {
    try {
      MultipartFile? contactsMultipart;
      File contactsConvertedFile = File(filePath);
      contactsMultipart =
          await MultipartFile.fromFile(contactsConvertedFile.path);
      FormData formData = FormData.fromMap({
        // "aadhar_number": userProfileProvider.user?.aadhaarNumber,
        "file": contactsMultipart,
      });
      final response = await HttpService().postDocs(
        GlobalState().serverPath(
          'api/v1/runners/me/referral_sync',
        ),
        formData: formData,
        headers: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> uploadAppsFile(String filePath) async {
    try {
      MultipartFile? appsMultipart;
      File appsConvertedFile = File(filePath);
      appsMultipart = await MultipartFile.fromFile(appsConvertedFile.path);
      FormData formData = FormData.fromMap({
        "file": appsMultipart,
      });
      final response = await HttpService().postDocs(
        GlobalState().serverPath(
          'api/v1/runners/me/app_sync',
        ),
        formData: formData,
        headers: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> markArrival(String? filePath, int? jobId) async {
    try {
      MultipartFile? multipartFile;
      File convertedFile = File(filePath!);
      multipartFile = await MultipartFile.fromFile(convertedFile.path);
      // Fetching the current location of runner
      final position = await fetchCurrentLocation();
      FormData formData = FormData.fromMap({
        // "aadhar_number": userProfileProvider.user?.aadhaarNumber,
        "file": multipartFile,
      });

      if (position != null) {
        formData = FormData.fromMap({
          // "aadhar_number": userProfileProvider.user?.aadhaarNumber,
          "file": multipartFile,
          'location': {
            'lat': position.latitude,
            'lng': position.longitude,
          }
        });
      }

      final response = await HttpService().postDocs(
        GlobalState().serverPath(
          'api/v1/jobs/$jobId/mark_arrival',
        ),
        formData: formData,
        headers: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> shiftLogin(LoginSelfie? loginSelfie) async {
    try {
      MultipartFile? multipartFile;
      File convertedFile = File(loginSelfie!.selfie!.path);
      multipartFile = await MultipartFile.fromFile(convertedFile.path);
      FormData formData = FormData.fromMap({
        // "aadhar_number": userProfileProvider.user?.aadhaarNumber,
        "file": multipartFile,
      });
      final response = await HttpService().postDocs(
        GlobalState().serverPath(
          'api/v1/runners/me/shift/login?lat=${loginSelfie.lat}&lng=${loginSelfie.lng}',
        ),
        formData: formData,
        headers: {},
      );

      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> acknowledgeAutoLogin({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState()
            .serverPath("api/v1/runners/me/shift/auto_login/acknowledge"),
        headers: headers ?? {},
        data: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> cancelAutoLogin({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/runners/me/shift/auto_login/cancel"),
        headers: headers ?? {},
        data: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> unsuspend({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().serverPath("api/v1/runners/me/unsuspend"),
        headers: headers ?? {},
        data: {},
      );
      return response;
    } catch (e) {
      try {
        MonitoringServiceHelper.logError('unsuspend_http_error', {
          'error': e.toString(),
        });
      } catch (_) {}
      return null;
    }
  }

  // static Future<Response?> runnerLoginLocation(XFile selfie) async {
  //   try {
  //     final File imgPath = File(selfie.path);
  //     final String fileName = selfie.name;
  //     var multipartFile = await http.MultipartFile.fromPath(
  //         'files', imgPath.path,
  //         filename: fileName);

  //     FormData data = FormData.fromMap({"file": multipartFile});

  //     final response = await Dio().post(
  //       GlobalState().serverPath("api/v1/runners/me/shift/login"),
  //       data: data,
  //     );
  //     // if (response.statusCode == 200) {
  //     Logger().i(response.statusCode);
  //     Logger().i(response.statusMessage);

  //     Logger().i(response.data);
  //     return response;
  //     // } else {
  //     //   return response;
  //     // }
  //   } catch (e) {
  //     // debugPrint(e.toString());
  //     return null;
  //   }
  // }

  static Future<Response?> goLive(File? file) async {
    try {
      MultipartFile? multipartFile;
      multipartFile = await MultipartFile.fromFile(
        file!.path,
        filename: "file.jpeg",
      );
      FormData formData = FormData.fromMap({
        // "aadhar_number": userProfileProvider.user?.aadhaarNumber,
        'file': multipartFile,
      });
      final response = await HttpService().postDocs(
        GlobalState().serverPath(
          'api/v1/runners/me/activate',
        ),
        formData: formData,
        headers: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getPrivacyPolicy() async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/me/privacy_policy"),
        headers: {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> todayShiftPerformance({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/me/current_shift_performance"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> fetchInfoBanners({
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath("api/v1/runners/info_banners"),
        headers: headers ?? {},
      );
      if (response.statusCode == 200) {
        return response;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

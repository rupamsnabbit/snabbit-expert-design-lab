import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:snabbit_runner/services/analytics/analytics_service.dart';
import 'package:snabbit_runner/services/job_overlay_channel.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/profile_sync_channel.dart';
import 'package:snabbit_runner/services/remote_config/kmp_remote_config_mirror.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/providers/banner_config_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/models/critical_field.dart';
import 'package:snabbit_runner/models/insurance_data.dart';
import 'package:snabbit_runner/models/training_center.dart';
import 'package:snabbit_runner/pages/login/select_language_v2.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/pages/signup/prior_experience.dart';
import 'package:snabbit_runner/pages/signup/training_progress.dart';
import 'package:snabbit_runner/pages/signup/training_slots.dart';
import 'package:snabbit_runner/pages/verification_display.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/webview/bifrost_handlers/set_rate_card_opted_in_handler.dart'
    show kAlreadyDidV2OptInPrefsKey;
import 'package:snabbit_runner/services/server_requests/registration_details_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/nav_observer.dart';
import 'package:snabbit_runner/utils/navigation_utils.dart';
import 'package:snabbit_runner/utils/registration_navigation.dart';
import 'package:snabbit_runner/utils/runner_registration_step.dart';

import '../models/hood.dart';
import '../services/integrity_test/models.dart';
import '../services/runner_http.dart';
import '../services/security/secure_storage_service.dart';
import '../utils/enums.dart';
import '../utils/rate_card_utils.dart';

class UserProfileProvider with ChangeNotifier {
  UserProfile? _user;
  String? error;
  bool loading = false;

  UserProfile? get user => _user;

  /// Top-level gate for the Vishwaas rate-card banner — drives both the
  /// drawer banner ([VishwaasDrawerBanner]) and the provisional-attendance
  /// bottom sheet ([showVishwaasProvisionalRateCardIfNeeded]).
  ///
  /// Four conditions must hold:
  /// 1. Runner has NOT already opted into v2 in this app session
  ///    ([kAlreadyDidV2OptInPrefsKey] in SharedPreferences). Set by the
  ///    webview via the `setRateCardOptedIn` bifrost message
  ///    immediately after a successful upgrade API call. This is the
  ///    short-lived local override that hides the surfaces between
  ///    the upgrade write and the next `runners/me` refresh; once
  ///    `runners/me` returns v2, gate 3 below also kicks in and this
  ///    flag becomes redundant (but harmless).
  /// 2. Remote Config flag `expert_enable_vishwaas_rate_card_banner` is
  ///    `true` (default `false` — flag has to be flipped on for the
  ///    feature to render).
  /// 3. Runner is on rate card v1 — v2 runners are already on the new
  ///    card and don't need the nudge.
  /// 4. Runner is NOT earning less on v2 ([UserProfile.hasLowerEarnings
  ///    InNewRateCard]) — don't push runners toward a card that's
  ///    earning them less.
  bool get showVishwaasBanner {
    // Gate 1 — local opt-in flag set by the webview.
    final prefs = GlobalState().prefs;
    if (prefs?.getBool(kAlreadyDidV2OptInPrefsKey) == true) return false;

    final rcEnabled = RemoteConfigService.instance.getBool(
      RemoteConfigKeys.enableVishwaasRateCardBanner,
      defaultValue: false,
    );
    if (!rcEnabled) return false;
    if (user?.hasLowerEarningsInNewRateCard == true) return false;
    return shouldShowVishwaasBanner(
        user?.rateCardVersion ?? RateCardVersion.v1);
  }

  bool get optedForNewRateCard =>
      isOptedForNewRateCard(user?.rateCardVersion ?? RateCardVersion.v1);

  /// `true` once the runner's v2 rate card has actually started taking
  /// effect. Use this for surfaces that should only appear after the
  /// new rate card is live (e.g. the drawer "Rate card" item) — not
  /// just after the runner opts in.
  bool get isRateCardV2Effective => user?.isRateCardV2Effective == true;

  /// In-flight post-login Remote Config targeting refresh. Config-gated
  /// navigation awaits this (via [ensureTargetingApplied]) so it reads fresh
  /// values instead of racing the fire-and-forget refresh.
  Future<void>? _targetingRefresh;

  set user(UserProfile? newUser) {
    _user = newUser;
    notifyListeners();

    // Surface the per-runner Android force-update floor to GlobalState so the
    // update check honours the stricter of this and the global app_config floor.
    // Placed here so every flow that loads /me (launch, login, refresh) applies it.
    GlobalState().runnerMinAndroidVersion =
        newUser?.runnerAppConfig?.minAndroidVersion;
    GlobalState().runnerSkipAndroidVersion =
        newUser?.runnerAppConfig?.skipAndroidVersion;

    // Set Firebase Analytics user properties for Remote Config targeting,
    // then re-fetch Remote Config so conditions match immediately.
    // Placed here so every flow that sets user data triggers this.
    _targetingRefresh =
        newUser != null ? _setUserPropertiesAndRefetchConfig(newUser) : null;

    // Attribute the current RUM/observability session (Coralogix + base14
    // Scout) to this runner. Single choke-point: fresh login, persisted-
    // profile hydrate on app boot, and every `/runners/me` refresh all pass
    // through here, so returning users don't end up as anonymous sessions.
    if (newUser != null) {
      unawaited(MonitoringServiceHelper.setUserDataAcrossServices(newUser));
    }
  }

  /// Awaits the post-login targeting refresh (bounded by [timeout]) so a
  /// config-gated route reads fresh values. Times out gracefully rather than
  /// blocking login indefinitely; the refresh still completes in the
  /// background, so a timed-out value will be correct on the next read.
  Future<void> ensureTargetingApplied({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final refresh = _targetingRefresh;
    if (refresh == null) return;
    try {
      await refresh.timeout(timeout);
    } catch (_) {
      // Slow/failed fetch — proceed with best-available config.
    }
  }

  /// Fingerprint of every input a Remote Config condition can target, used to
  /// decide whether a throttle-bypassing refetch is warranted.
  ///
  /// [versionCode] participates because `app_version_code` is a targeting user
  /// property too (see `AnalyticsService.setAppVersionProperties`). An upgrade
  /// is precisely when version conditions must re-evaluate, and it is the one
  /// targeting change the profile fields can't detect — without it a freshly
  /// upgraded install keeps serving config evaluated against the previous
  /// build until the 1h fetch throttle lapses.
  ///
  /// A null [versionCode] (boot's PackageInfo read failed) stringifies stably,
  /// so it degrades to "no forced refetch" rather than one on every launch.
  @visibleForTesting
  static String targetingSignature({
    required int? clusterId,
    required int? regionId,
    required int? trainingCenterId,
    required int? serviceId,
    required int? versionCode,
  }) =>
      [clusterId, regionId, trainingCenterId, serviceId, versionCode].join('|');

  /// Sets analytics user properties and re-fetches Remote Config
  /// so that server-side conditions can evaluate against the latest values.
  Future<void> _setUserPropertiesAndRefetchConfig(UserProfile user) async {
    try {
      AnalyticsService.instance.setUserTargetingProperties(
        clusterId: user.clusterId,
        regionId: user.regionId,
        trainingCenterId: user.tc?.id,
        // Falls back to the top-level serviceId if the nested service
        // object is absent — some `runners/me` payloads send only one.
        serviceId: user.service?.id ?? user.serviceId,
      );

      // Push the runner's service_id to the native job launcher so the KMP New-Job header shows the
      // Cook vs Expert glyph (best-effort; JobOverlayChannel swallows channel failures).
      JobOverlayChannel.setServiceId(user.service?.id ?? user.serviceId);
      // And the runner's id — the KMP delayed check-in disposition's runner_id (the
      // envelope doesn't carry it; Dart's UserProfileProvider is its only source).
      JobOverlayChannel.setRunnerId(user.id);

      // Force a throttle-bypassing fetch only when targeting actually changed
      // (incl. first login: unknown -> known); otherwise the normal throttled
      // fetch. Persisted so we don't force-fetch on every cold launch.
      const signatureKey = 'rc_last_targeting_signature';
      final signature = targetingSignature(
        clusterId: user.clusterId,
        regionId: user.regionId,
        trainingCenterId: user.tc?.id,
        serviceId: user.service?.id ?? user.serviceId,
        // Boot populates this long before profile hydrate (main.dart), so it
        // is available here without a second PackageInfo read.
        versionCode: GlobalState().latestVersionCode,
      );
      final prefs = await SharedPreferences.getInstance();
      final targetingChanged = prefs.getString(signatureKey) != signature;
      if (targetingChanged) {
        await RemoteConfigService.instance.forceRefetch();
        await prefs.setString(signatureKey, signature);
      } else {
        await RemoteConfigService.instance.fetchAndActivate();
      }
      // Post-login targeting may have changed the KMP-relevant RC flags — mirror
      // the fresh snapshot into the KMP module (fire-and-forget).
      unawaited(KmpRemoteConfigMirror.push());

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = GlobalState().navigatorKey.currentContext;
        if (context != null) {
          Provider.of<BannerConfigProvider>(context, listen: false)
              .loadBanners();
        }
      });
    } catch (_) {}
  }

  set age(int? val) {
    _user?.age = val;
    notifyListeners();
  }

  // set youngestChildAge(int? val) {
  //   _user?.youngestChildAge = val;
  //   notifyListeners();
  // }

  set tc(TrainingCenter? val) {
    _user?.tc = val;
    notifyListeners();
  }

  set languagePreference(String? val) {
    _user?.languagePreference = val;
    notifyListeners();
  }

  set panCardUnavailable(bool value) {
    _user?.panCardUnavailable = value;
    notifyListeners();
  }

  Future<void> runnersMeSetup() async {
    try {
      loading = true;
      notifyListeners();
      Response? response = await RunnerHttp.runnersMe();
      if (response?.statusCode == 200) {
        user = UserProfile.fromMap(response?.data);
        // Store runner_id in SharedPreferences for IoT background service
        if (user != null) {
          final userId = user!.id.toString();
          try {
            final secureStorage = SecureStorageService();
            await secureStorage.saveUserId(userId);
          } catch (e) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(AppStrings.userId, userId);
            MonitoringServiceHelper.logError("SECURE_STORAGE_SERVICE_FAILED", {
              'task': "SAVING_USER_ID",
              'error': e.toString(),
            });
          }
        }
        // Push the raw runners/me body to the native KMP stores so the Compose
        // Profile / Earnings / Refer surfaces read it — KMP does NOT fetch runners/me
        // itself (Dart owns the single call, avoiding a double API hit). A cleared
        // bank/PAN/Aadhaar nudge disappears because the native side re-decodes this push.
        // Best-effort: the channel swallows + logs any failure so it never breaks refresh.
        await ProfileSyncChannel.pushProfile(jsonEncode(response?.data));
      } else {
        // Surface the failure to KMP so the native Profile shows its error state
        // immediately (no-ops on the native side if content is already loaded).
        await ProfileSyncChannel.pushProfileError(
          'runners_me_status_${response?.statusCode}',
        );
      }
    } catch (e) {
      MonitoringServiceHelper.logError("RUNNERS_ME_SETUP_FAILED", {
        'error': e.toString(),
      });
      await ProfileSyncChannel.pushProfileError('runners_me_exception');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> resetRegistrationAndRefresh() async {
    bool success = false;
    try {
      final response = await RunnerHttp.resetRegistration();
      if (response?.statusCode == 404) {
        await runnersMeSetup();
        return true;
      }
      success = response?.statusCode == 200 || response?.statusCode == 204;
    } catch (e) {
      MonitoringServiceHelper.logError("RESET_REGISTRATION_FAILED", {
        'error': e.toString(),
      });
    }
    await runnersMeSetup();
    return success;
  }

  Future<void> checkStatusAndNavigate(BuildContext context) async {
    await runnersMeSetup();

    if (!context.mounted) return;

    await RegistrationNavigation.navigateAfterRunnersMe(context);
  }

  Document? getAadharFrontDocument() {
    try {
      final defaultDoc =
          Document(number: null, type: DocumentStrings.aadhaarFront);
      if (user?.documents == null || user?.documents.isEmpty == true) {
        user?.documents.add(defaultDoc);
        return user?.documents.last;
      }
      int? matchingIndex = user?.documents.indexWhere(
        (element) => element.type == DocumentStrings.aadhaarFront,
      );
      if (matchingIndex == -1) {
        user?.documents.add(defaultDoc);
        return user?.documents.last;
      } else {
        return user?.documents[matchingIndex!];
      }
    } catch (e) {
      return null;
    }
  }

  Document? getAadharBackDocument() {
    try {
      final defaultDoc =
          Document(number: null, type: DocumentStrings.aadhaarBack);
      if (user?.documents == null || user?.documents.isEmpty == true) {
        user?.documents.add(defaultDoc);
        return user?.documents.last;
      }
      int? matchingIndex = user?.documents.indexWhere(
        (element) => element.type == DocumentStrings.aadhaarBack,
      );
      if (matchingIndex == -1) {
        user?.documents.add(defaultDoc);
        return user?.documents.last;
      } else {
        return user?.documents[matchingIndex!];
      }
    } catch (e) {
      return null;
    }
  }

  void updateDocumentVerification(bool value, Document? document) {
    document?.verified = value;
    notifyListeners();
  }

  void updatePresignedUrl(String? value, Document? document) {
    document?.presignedUrl = value;
    notifyListeners();
  }

  Future<Response?> submitDocs(
      {required BuildContext context,
      String? aadharFrontImage,
      String? aadharBackImage,
      String? panImage,
      required Function(Response?) onError}) async {
    // bool result;
    try {
      MultipartFile? aadharFrontMultipart;
      MultipartFile? aadharBackMultipart;
      MultipartFile? panMultipart;

      if (aadharFrontImage != null) {
        File aadharFrontConvertedFile = File(aadharFrontImage);
        aadharFrontMultipart =
            await MultipartFile.fromFile(aadharFrontConvertedFile.path);
      }

      if (aadharBackImage != null) {
        final aadharBackConvertedFile = File(aadharBackImage);
        aadharBackMultipart =
            await MultipartFile.fromFile(aadharBackConvertedFile.path);
      }

      if (panImage != null) {
        final panConvertedFile = File(panImage);
        panMultipart = await MultipartFile.fromFile(panConvertedFile.path);
      }

      // Convert files to MultipartFile
      final aadharFrontDoc = getAadharFrontDocument();
      final aadharBackDoc = getAadharBackDocument();
      String? aadharNumber = aadharFrontDoc?.number;
      // String? panNumber = panDoc?.number;

      // Create form data
      FormData formData = FormData.fromMap({
        // "aadhar_number": userProfileProvider.user?.aadhaarNumber,
        "aadhar_number": aadharNumber,
        "aadhar_front_file": aadharFrontMultipart,
        "aadhar_back_file": aadharBackMultipart,
        "pan_number": user?.panCardUnavailable == true
            ? null
            // : userProfileProvider.user?.panNumber,
            : '',
        "pan_file": user?.panCardUnavailable == true ? null : panMultipart,
        "is_pan_skipped": user?.panCardUnavailable == true,
      });
      Response? response = await RegistrationDetailsHttp.submitIdDocs(
        formData,
      );

      if (response != null && response.statusCode == 200) {
        if (context.mounted) {
          user = UserProfile.fromMap(response.data);

          await RegistrationNavigation.navigateToRegistrationStep(context);
        }
      } else {
        onError(response);
      }
    } catch (e) {
      if (context.mounted) {
        showSnackbar(
          context,
          "Document upload failed. Try again!",
        );
      }
      return null;
    }
  }

  Address? getCurrentAddress() {
    try {
      // Return existing current address if it exists
      if (user?.addresses != null) {
        for (final address in user!.addresses!) {
          if (address.type == AddressType.current) {
            return address;
          }
        }
      }

      // Return default address without adding to the list
      return Address(id: -1, type: AddressType.current);
    } catch (e) {
      return null;
    }
  }

  Address? getPermanentAddress() {
    try {
      if (user?.addresses != null) {
        for (final address in user!.addresses!) {
          if (address.type == AddressType.permanent) {
            return address;
          }
        }
      }

      return Address(id: -1, type: AddressType.permanent);
    } catch (e) {
      return null;
    }
  }

  Future<void> runnerRegistrationAndErrorHandler({
    required BuildContext context,
    Function()? onSuccess,
    required Function(
      String? errorMessage,
    ) onError,
    bool navigateNext = true,
    bool isFirstRoute = false,
  }) async {
    try {
      loading = true;
      notifyListeners();
      Map<String, dynamic>? data = user?.toMap();
      if (isFirstRoute) {
        data?['registration_step'] = RunnerRegistrationStep.startRegistration;
      }
      RunnerState? previousStatus = user?.runnerStatus;
      bool? statusChanged;
      Response? response = await RunnerHttp.runnerRegistration(
        data: data,
      );
      loading = false;
      notifyListeners();
      if (response != null && response.statusCode == 200) {
        error = null;
        if (context.mounted) {
          user = UserProfile.fromMap(response.data);
          statusChanged = user?.runnerStatus != null &&
              previousStatus != null &&
              user?.runnerStatus != previousStatus;
          if (onSuccess != null) {
            onSuccess();
          }
          if (navigateNext == true) {
            if (user?.registrationCompleted == true || statusChanged == true) {
              if (user?.runnerStatus == RunnerState.REGISTERED) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                    TrainingSlots.routeName,
                    (route) =>
                        route.settings.name == SelectLanguageV2.routeName ||
                        route.settings.name == "/");
              } else if ((user?.runnerStatus == RunnerState.CREATED ||
                      user?.runnerStatus == RunnerState.TRAINING) &&
                  user?.registrationStep?.rawStep ==
                      RunnerRegistrationStep.onboardingV2) {
                NavigationUtils.openTrainingWebView(
                  context: context,
                  replace: true,
                );
              } else {
                Navigator.of(context)
                    .pushReplacementNamed(VerificationDisplay.routeName);
              }
            } else if (user?.runnerStatus == RunnerState.FAILED) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                  VerificationDisplay.routeName, (route) => false);
            } else if (isFirstRoute == true) {
              /// This is a special case
              if (user?.runnerStatus == RunnerState.REGISTERED) {
                Navigator.of(context).pushNamed(TrainingSlots.routeName);
              } else if ((user?.runnerStatus == RunnerState.CREATED ||
                      user?.runnerStatus == RunnerState.TRAINING) &&
                  user?.registrationStep?.rawStep ==
                      RunnerRegistrationStep.onboardingV2) {
                // replace:true so the hub clears any stale onboarding hub on
                // the stack (matches the registrationCompleted branch above) —
                // otherwise a legacy native hub can sit beneath the webview and
                // resurface on back-out.
                NavigationUtils.openTrainingWebView(
                  context: context,
                  replace: true,
                );
              } else {
                await RegistrationNavigation.navigateToRegistrationStep(
                  context,
                );
              }
            } else {
              await RegistrationNavigation.navigateToRegistrationStep(context);
            }
          }
        }
      } else {
        try {
          error = response?.data['errors'][0]['message'];
        } catch (e) {
          error = "Server error - ${response?.statusCode}";
        }
        onError(error);
        notifyListeners();
      }
    } catch (e) {
      error = "Something went wrong $e";
      onError(error);
      notifyListeners();
    }
  }

  Future<void> registrationBackAction() async {
    try {
      Response? response = await RunnerHttp.runnerRegistrationPreviousStep();
      if (response != null && response.statusCode == 200) {
        user = UserProfile.fromMap(response.data);
        final ctx = GlobalState().navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          await RegistrationNavigation.navigateToRegistrationStep(ctx);
        }
      } else {
        if (user?.runnerStatus == RunnerState.REGISTERED) {
          // DO NOTHING
        } else {
          showSnackbar(GlobalState().navigatorKey.currentContext!,
              response?.data['errors'][0]['message']);
          Navigator.of(GlobalState().navigatorKey.currentContext!)
              .pushReplacementNamed(NavObserver.prevRoute!.settings.name!);
        }

        /// BACK action to SelectLanguage
      }
    } catch (e) {
      /// BACK action to SelectLanguage
    }
    Future.delayed(const Duration(milliseconds: 250)).then((_) {
      loading = false;
      notifyUserListeners();
    });
  }

  Future<void> editDetailsReviewAction() async {
    try {
      loading = true;
      notifyListeners();
      Response? response = await RunnerHttp.editDetailsReviewAction();
      loading = false;
      notifyListeners();
      if (response != null && response.statusCode == 200) {
        user = UserProfile.fromMap(response.data);
        final ctx = GlobalState().navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          await RegistrationNavigation.navigateToRegistrationStep(
            ctx,
            replace: true,
          );
        }
      } else {
        showSnackbar(GlobalState().navigatorKey.currentContext!,
            response?.data['errors'][0]['message']);
      }
    } catch (e) {
      try {
        showSnackbar(GlobalState().navigatorKey.currentContext!, e.toString());
      } catch (e) {
        // DO NOTHING
      }
    }
  }

  set consentGiven(bool value) {
    _user?.consentGiven = value;
    notifyListeners();
  }

  void updateBankVerificationState(bool value) {
    user?.bankVerified = value;
    notifyListeners();
  }

  void notifyUserListeners() {
    notifyListeners();
  }

  bool get shouldShowTiering =>
      user?.hasViewedIntro == true &&
      user?.isTieringEnabled == true &&
      user?.serviceId == 1 &&
      user?.runnerStatus != RunnerState.SUSPENDED;
}

class UserProfile {
  int id;
  bool isActive;
  String phoneNumber;
  String countryCode;
  String? name;
  CF<Gender>? gender;
  DateTime? joiningDate;
  RegistrationStep? registrationStep;
  RunnerState? runnerStatus;
  String? languagePreference;

  /// Raw `mqtt_config` object from `GET /runners/me` (MQTT realtime rollout).
  /// Non-null ⇒ this runner is in the MQTT (realtime) cohort and is routed into
  /// the KMP navigation stack at login; null/absent ⇒ polling cohort (Flutter
  /// PartnerHome). Kept as a raw map — Dart only checks presence to route; the
  /// KMP side reads the broker fields (host/port/topics) on its own track.
  final Map<String, dynamic>? mqttConfig;

  // Gates the localized notification audio. Comes from /runners/me as
  // an enum serializing to the lowercase string `"v1"` / `"v2"`.
  // `null` (or anything that isn't `v2`, trimmed + case-insensitive)
  // keeps the legacy audio (nudge_count-based for job acceptance,
  // `awol_job_alarm.mp3` for NOT_GOING_TO_JOB_BREACH). `"v2"` switches
  // both sounds to the language-specific files under
  // `assets/notification_sounds/<lang>/`. See
  // LocalizedAudioService.useLocalizedAudio.
  String? audioVersion;
  List<Address>? addresses;

  // Address? permanentAddress;
  Service? service;
  MaritalStatus? maritalStatus;
  CF<DateTime>? dob;
  String? alternatePhoneNumber;
  BooleanCF? petAverse;
  String? bankAccountName;
  String? bankAccountNumber;
  String? bankIfscCode;
  String? verifiedBeneficiaryName;
  String? accountType;
  Nominee? nominee;
  String? generalShiftStart; // TODO maybe DateTime or TimeOfDay
  String? generalShiftEnd; // TODO maybe DateTime or TimeOfDay
  int? rateCard;
  String? referralPhoneNumber;
  bool? agreedTnc;
  bool? isSuspended;
  DateTime? suspensionDate;
  bool? onDuty;
  List<Document> documents;
  List<DefaultShift> defaultShifts;
  RunnerOtherDetails? otherDetails;
  bool? syncReferral;
  String? publicPic;
  List<RunnerIntegrityTestAnswers>? integrityTestAnswers;
  RunnerAppConfig? runnerAppConfig;
  double? realAvgRating;
  String? registrationCode;
  String? onboardingAgentCode;
  AlternateDeliveryMethod? alternateDeliveryMethod;

  ///
  int? age;
  TrainingCenter? tc;
  int? clusterId;
  int? regionId;

  // int? youngestChildAge;
  TrainingSlot? trainingSlot;
  bool panCardUnavailable;
  bool? registrationCompleted;
  bool? bankVerified;
  bool? isPanVerified;
  HotSpot? hotSpot;

  //TODO: Payout related: check if this property is still valid
  bool? panAadharLinked;

  Tier? tier;

  ///
  String? fatherName;
  String? yob;

  InsuranceData? insuranceData;
  double? currentMonthRating;
  bool? showPhoneNumber;
  CF<WorkSchedule>? workSchedule;
  String? pan;
  bool? consentGiven;
  bool safetyShieldEnabled;
  String? consentAt;
  bool? isLoanEligible;
  int? serviceId;
  DateTime? tierEffectiveDate;

  /// `true` when the runner must re-verify (re-KYC) their Aadhaar for
  /// compliance. Gates the drawer entry point and the suspended-screen
  /// reactivation path. Wire format: top-level `is_aadhaar_rekyc` boolean on
  /// the `runners/me` response. The backend flips this to `false` and
  /// reactivates the runner once verification succeeds — the app only refreshes.
  bool? isAadhaarRekyc;

  RateCardVersion rateCardVersion;

  /// Month the runner opted into their current rate card version. Wire
  /// format is `MM/YYYY` (e.g. `"05/2026"`). `null` when the backend
  /// hasn't populated it (or the value failed to parse).
  String? rateCardOptinMonth;

  /// `true` when the runner is making LESS money on the new rate card
  /// than they were on the old one. When `true`, the Vishwaas
  /// rate-card promotion banner is suppressed (don't push runners
  /// toward a card that's earning them less). Defaults to `false`.
  ///
  /// Wire format: `has_lower_earnings_in_new_rate_card` boolean on the
  /// `runners/me` response.
  bool hasLowerEarningsInNewRateCard;

  /// `true` once the runner's v2 rate card has actually started taking
  /// effect (not just opted into). Drives drawer "Rate card" item
  /// visibility — we don't want to surface the rate card screen the
  /// moment a runner opts in, only after it begins applying to their
  /// earnings.
  ///
  /// Wire format: `is_rate_card_v2_effective` boolean on the
  /// `runners/me` response. Defaults to `false` when absent.
  bool isRateCardV2Effective;

  /// `true` once the runner has completed the one-time Tiers (Snabbit
  /// Coins) intro flow. Forwarded to web as `runner.hasSeenTierIntro` in
  /// the bifrost init-data payload so the Tiers webview module can gate
  /// the intro without a separate round trip.
  ///
  /// Wire format: `has_viewed_intro` boolean on the `runners/me` response.
  /// Defaults to `false` when absent.
  bool hasViewedIntro;

  bool? get isWashroomFinderEnabled => runnerAppConfig?.isWashroomFinderEnabled;
  bool? get isMerchStoreEnabled => runnerAppConfig?.isMerchStoreEnabled;
  String? get sevaUrl => runnerAppConfig?.webViewUrls?.seva;
  String? get merchStoreUrl => runnerAppConfig?.webViewUrls?.merchStore;

  bool get showSeva =>
      isWashroomFinderEnabled == true && (sevaUrl?.isNotEmpty ?? false);
  bool get showMerchStore =>
      isMerchStoreEnabled == true && (merchStoreUrl?.isNotEmpty ?? false);

  bool get isTieringEnabled {
    final effectiveDate = tierEffectiveDate;
    if (effectiveDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !effectiveDate.isAfter(today);
  }

  UserProfile({
    required this.id,
    this.isActive = true,
    required this.phoneNumber,
    required this.countryCode,
    this.name,
    this.gender,
    this.joiningDate,
    this.registrationStep,
    this.runnerStatus,
    this.languagePreference,
    this.mqttConfig,
    this.audioVersion,
    this.addresses = const [],
    this.service,
    this.maritalStatus,
    this.dob,
    this.alternatePhoneNumber,
    this.petAverse,
    this.bankAccountName,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.verifiedBeneficiaryName,
    this.accountType,
    this.nominee,
    this.generalShiftStart,
    this.generalShiftEnd,
    this.rateCard,
    this.referralPhoneNumber,
    this.agreedTnc,
    this.isSuspended,
    this.suspensionDate,
    this.onDuty,
    this.documents = const [],
    this.defaultShifts = const [],
    this.otherDetails,
    this.syncReferral,
    this.publicPic,
    this.integrityTestAnswers,
    this.runnerAppConfig,
    this.realAvgRating,
    this.registrationCode,
    this.onboardingAgentCode,
    this.age,
    this.tc,
    this.clusterId,
    this.regionId,
    // this.youngestChildAge,
    this.panCardUnavailable = false,
    this.trainingSlot,
    this.bankVerified,
    this.registrationCompleted,
    this.hotSpot,
    this.panAadharLinked,
    this.tier,
    this.isPanVerified,
    this.fatherName,
    this.alternateDeliveryMethod,
    this.insuranceData,
    this.yob,
    this.currentMonthRating,
    this.showPhoneNumber,
    this.workSchedule,
    this.pan,
    this.consentGiven,
    this.safetyShieldEnabled = false,
    this.consentAt,
    this.isLoanEligible,
    this.serviceId,
    this.tierEffectiveDate,
    this.isAadhaarRekyc,
    this.rateCardVersion = RateCardVersion.v1,
    this.rateCardOptinMonth,
    this.hasLowerEarningsInNewRateCard = false,
    this.isRateCardV2Effective = false,
    this.hasViewedIntro = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'gender': gender?.value == Gender.MALE
          ? 'M'
          : gender?.value == Gender.FEMALE
              ? 'F'
              : null,
      'joining_date': getStringFromDateTime(joiningDate),
      "verification_status": runnerStatus?.name,
      'language_preference': languagePreference,
      'audio_version': audioVersion,
      'user': {
        'name': name,
        'country_code': countryCode,
        'phone': phoneNumber,
      },
      'addresses': addresses
          ?.map(
            (e) => e.toMap(),
          )
          .toList(),
      'service': service?.toMap(),
      'marital_status': maritalStatus?.name,
      'dob': getStringFromDateTime(dob?.value),
      'alternate_phone_number': alternatePhoneNumber,
      'pet_averse': petAverse?.value,
      'bank_account_name': bankAccountName,
      'bank_account_number': bankAccountNumber,
      'bank_ifsc_code': bankIfscCode,
      'verified_beneficiary_name': verifiedBeneficiaryName,
      'account_type': accountType,
      'nominee_details': nominee?.toMap(),
      'general_shift_start': generalShiftStart,
      'general_shift_end': generalShiftEnd,
      'rate_card': rateCard,
      'referral_phone_number': referralPhoneNumber,
      'agreed_tnc': agreedTnc,
      'is_suspended': isSuspended,
      'suspension_date': getStringFromDateTime(suspensionDate),
      'on_duty': onDuty,
      'documents': documents.map((e) => e.toMap()).toList(),
      'default_shifts': defaultShifts.map((e) => e.toMap()).toList(),
      'other_details': otherDetails?.toMap(),
      'public_pic': publicPic,
      'answers': integrityTestAnswers?.map((e) => e.toMap()).toList(),
      'real_avg_rating': realAvgRating,
      'registration_code': registrationCode,
      'onboarding_agent_code': onboardingAgentCode,
      'age': age,
      'training_center_id': tc?.id,
      'cluster_id': clusterId,
      'region_id': regionId,
      // 'youngest_child_age': youngestChildAge,
      'pan_card_unavailable': panCardUnavailable,
      'training_slot': trainingSlot?.toMap(),
      'registration_completed': registrationCompleted,
      'bank_verified': bankVerified,
      'pan_verified': isPanVerified,
      'pan_aadhar_linked': panAadharLinked,
      'tier': tier?.name,
      'father_name': fatherName,
      'insurance': insuranceData?.toMap(),
      'yob': yob,
      'current_month_rating': currentMonthRating,
      'work_schedule': workSchedule?.value?.key.toUpperCase(),
      'pan': pan,
      'safety_shield': {
        'consent_given': consentGiven,
        'enabled': safetyShieldEnabled,
        'consent_at': consentAt,
      },
      'service_id': serviceId,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> userJson) {
    return UserProfile(
      id: userJson['user']['id'],
      isActive: userJson['user']['is_active'],
      phoneNumber: userJson['user']['phone'],
      countryCode: userJson['user']['country_code'],
      name: userJson['user']['name'],
      gender: CF<Gender>(
        value: getGenderFromString(userJson['gender']),
        key: 'gender',
        acceptedValues: GlobalState()
                .appConfig
                ?.getCriticalField('gender')
                ?.map(
                  (gender) => getGenderFromString(gender),
                )
                ?.toList() ??
            [],
      ),
      joiningDate: getDateTimeFromServerString(userJson['joining_date']),
      registrationStep: userJson['registration_step_details'] != null
          ? RegistrationStep.fromMap(userJson['registration_step_details'])
          : null,
      runnerStatus: RunnerState.fromString(userJson['status']),
      languagePreference: userJson['language_preference'],
      mqttConfig: userJson['mqtt_config'] is Map
          ? Map<String, dynamic>.from(userJson['mqtt_config'] as Map)
          : null,
      audioVersion: userJson['audio_version'],
      addresses: userJson['addresses']
              ?.map<Address>(
                (e) => Address.fromMap(e),
              )
              .toList() ??
          [],
      service: userJson['service'] != null
          ? Service.fromMap(userJson['service'])
          : null,
      maritalStatus: getMaritalStatusFromString(userJson['marital_status']),
      dob: CF<DateTime>(
        value: getDateTimeFromServerString(userJson['dob']),
        key: 'dob',
        acceptedValues: List<int>.from(
            GlobalState().appConfig?.getCriticalField('age_range') ?? []),
      ),
      alternatePhoneNumber: userJson['alternate_phone_number'],
      petAverse: BooleanCF(
        value: userJson['pet_averse'],
        key: 'pet_averse',
        acceptedValue: GlobalState().appConfig?.getCriticalField('pet_averse'),
      ),
      bankAccountName: userJson['bank_account_name'],
      bankAccountNumber: userJson['bank_account_number'],
      bankIfscCode: userJson['bank_ifsc_code'],
      verifiedBeneficiaryName: userJson['verified_beneficiary_name'],
      accountType: userJson['account_type'],
      nominee: userJson['nominee_details'] != null
          ? Nominee.fromMap(userJson['nominee_details'])
          : Nominee(),
      generalShiftStart: userJson['general_shift_start'],
      generalShiftEnd: userJson['general_shift_end'],
      rateCard: userJson['rate_card'],
      referralPhoneNumber: userJson['referral_phone_no'].toString(),
      agreedTnc: userJson['agreed_tnc'],
      isSuspended: userJson['is_suspended'],
      suspensionDate: getDateTimeFromServerString(userJson['suspension_date']),
      onDuty: userJson['on_duty'],
      documents: userJson['documents'].map<Document>((e) {
        if (e['type'] == DocumentStrings.aadhaarBack ||
            e['type'] == DocumentStrings.aadhaarFront) {
          e['verified'] = userJson['aadhaar_verified'];
        } else if (e['type'] == DocumentStrings.pan) {
          e['verified'] = userJson['pan_verified'];
        }
        return Document.fromMap(e as Map<String, dynamic>);
      }).toList(),
      defaultShifts: userJson['default_shifts']
          .map<DefaultShift>(
              (e) => DefaultShift.fromMap(e as Map<String, dynamic>))
          .toList(),
      otherDetails: userJson['other_details'] == null
          ? RunnerOtherDetails()
          : RunnerOtherDetails.fromMap(userJson['other_details']),
      syncReferral: userJson['sync_referral'],
      publicPic: userJson['public_pic'],
      integrityTestAnswers: userJson['onboarding_answers'] != null
          ? userJson['onboarding_answers']
              .map<RunnerIntegrityTestAnswers>(
                  (e) => RunnerIntegrityTestAnswers.fromMap(e))
              .toList()
          : [],
      runnerAppConfig: userJson['app_config'] != null
          ? RunnerAppConfig.fromMap(userJson['app_config'])
          : null,
      realAvgRating: userJson['real_avg_rating'],
      registrationCode: userJson['registration_code'],
      onboardingAgentCode: userJson['onboarding_agent_code'],
      age: anyValueToInt(userJson['age']),
      tc: userJson['training_center'] != null
          ? TrainingCenter.fromJson(userJson['training_center'])
          : null,
      clusterId: anyValueToInt(userJson['cluster_id']),
      regionId: anyValueToInt(userJson['region_id']),
      // youngestChildAge: userJson['age_of_youngest_child'],
      panCardUnavailable: userJson['pan_card_unavailable'] ?? false,
      trainingSlot: userJson['training_slot'] != null
          ? TrainingSlot.fromMap(userJson['training_slot'])
          : null,
      registrationCompleted: userJson['registration_completed'],
      bankVerified: userJson['bank_verified'] ?? false,
      isPanVerified: userJson['pan_verified'] ?? false,
      hotSpot: userJson['hotspot'] != null
          ? HotSpot.fromMap(userJson['hotspot'])
          : null,
      panAadharLinked: userJson['aadhaar_pan_linked'],
      tier: Tier.fromString(userJson['tier']),
      fatherName: userJson['father_name'],
      alternateDeliveryMethod:
          AlternateDeliveryMethod.fromString(userJson['adm']),
      insuranceData: userJson['insurance'] != null
          ? InsuranceData.fromMap(userJson['insurance'])
          : InsuranceData(),
      yob: userJson['yob'],
      currentMonthRating: userJson['current_month_rating'],
      showPhoneNumber: userJson['show_phone_number'] ?? true,
      workSchedule: CF<WorkSchedule>(
        value: WorkSchedule.fromString(userJson['work_schedule']),
        key: 'work_schedule',
        acceptedValues:
            GlobalState().appConfig?.getCriticalField('work_schedule'),
      ),
      pan: userJson['pan'],
      safetyShieldEnabled: userJson['safety_shield']?['enabled'] ?? false,
      consentGiven: userJson['safety_shield']?['consent_given'],
      consentAt: userJson['safety_shield']?['consent_at']?.toString(),
      isLoanEligible: userJson['is_loan_eligible'],
      serviceId: userJson['service_id'],
      tierEffectiveDate:
          getDateTimeFromServerString(userJson['tier_effective_date']?.toString()),
      isAadhaarRekyc: userJson['is_aadhaar_rekyc'],
      rateCardVersion: parseRateCardVersion(userJson['rate_card_version']),
      rateCardOptinMonth:
          parseRateCardOptinMonth(userJson['rate_card_optin_month']),
      // Defaults to `false` if the backend hasn't shipped this field
      // yet — once it lands, the JSON value takes precedence.
      hasLowerEarningsInNewRateCard:
          userJson['has_lower_earnings_in_new_rate_card'] as bool? ?? false,
      // Defaults to `false` until the runner's v2 rate card is
      // actually effective (not just opted in).
      isRateCardV2Effective:
          userJson['is_rate_card_v2_effective'] as bool? ?? false,
      hasViewedIntro: userJson['has_viewed_intro'] as bool? ?? false,
    );
  }
}

enum AddressType {
  current,
  permanent;

  static AddressType? fromString(String? type) {
    switch (type) {
      case "CURRENT":
        return AddressType.current;
      case "PERMANENT":
        return AddressType.permanent;
      default:
        return null;
    }
  }
}

class Address {
  int id; // TODO initialize id with -1
  String? addressLine1;
  String? placeId;
  AddressType? type;

  Address({
    required this.id,
    this.addressLine1,
    this.placeId,
    this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address_line_1': addressLine1,
      'place_id': placeId,
      'type': type?.name.toUpperCase()
    };
  }

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      id: map['id'],
      addressLine1: map['address_line_1'],
      placeId: map['place_id'],
      type: AddressType.fromString(map['type']),
    );
  }
}

class Service {
  int id;
  String name;

  Service({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      id: map['id'],
      name: map['name'],
    );
  }
}

DateTime? getDateTimeFromServerString(String? date) {
  try {
    return DateFormat('yyyy-MM-dd').parse(date!);
  } catch (e) {
    return null;
  }
}

String? getStringFromDateTime(DateTime? date) {
  try {
    return DateFormat('yyyy-MM-dd').format(date!);
  } catch (e) {
    return null;
  }
}

class Nominee {
  String? name;
  String? phone;
  String? relationship;
  String? otherRelationship;
  DateTime? dob;

  Nominee({
    this.name,
    this.phone,
    this.relationship,
    this.otherRelationship,
    this.dob,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'other_relationship': otherRelationship,
      'dob': getStringFromDateTime(dob),
    };
  }

  factory Nominee.fromMap(Map<String, dynamic> map) {
    return Nominee(
      name: map['name'],
      phone: map['phone'],
      relationship: map['relationship'],
      otherRelationship: map['other_relationship'],
      dob: getDateTimeFromServerString(map['dob']),
    );
  }
}

class Document {
  int? id;
  String? type;
  DocumentStatus? status;
  String? number;
  String? presignedUrl;
  String? expiresAt;
  bool? verified;

  Document({
    this.id,
    this.type,
    this.status,
    this.number,
    this.presignedUrl,
    this.expiresAt,
    this.verified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'number': number,
      'status': status?.name,
      'presigned_url': presignedUrl,
      'expires_at': expiresAt,
      'verified': verified
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'],
      type: map['type'],
      status: getDocumentStatusFromString(map['status']),
      number: map['number'],
      presignedUrl: map['presigned_url'],
      expiresAt: map['expires_at'],
      verified: map['verified'],
    );
  }
}

class DefaultShift {
  int id;
  int day;
  String startTime;
  String endTime;

  DefaultShift({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory DefaultShift.fromMap(Map<String, dynamic> map) {
    return DefaultShift(
      id: map['id'],
      day: map['day'],
      startTime: map['start_time'],
      endTime: map['end_time'],
    );
  }
}

class RunnerOtherDetails {
  CF<String>? spouseOccupation;
  CF<int>? spouseMonthlyIncome;
  bool? spouseApproval;
  bool? spouseKnowAboutJob;
  bool? stayWithInLaws;
  bool? inLawsApproval;
  CF<int>? numberOfChildren;
  DateTime? dobOfYoungestChild;
  CF? stayWithParents;
  CF? parentsApproval;

  // int? yearOfDivorce;
  ListCF<PriorJob>? priorJobs;
  int? lastDrawnSalary;
  ListCF<PlanToUseSalary>? planToUseSalary;
  Religion? religion;
  Sect? sect;
  NumberRangeCF? height;
  NumberRangeCF? weight;
  Education? highestEducation;
  CF<DietaryPreference>? dietaryPreference;
  CF<PetPreference>? petPreference;
  CF? filledItrLast2Years;
  CF? availability;
  CF? hoursAvailableToWork;
  CF? availableStartTime;
  CF? availableEndTime;
  bool? agreedTnc;
  bool? tellFamilyInFuture;
  List<ReadLevelLanguages>? canReadLanguages;
  BooleanCF? tshirtAllowed;
  BooleanCF? familyOkWithCleaningJob;
  BooleanCF? canCleanNonVegKitchen;
  BooleanCF? willingToCleanHomeWithPets;
  BooleanCF? willingToCleanBathrooms;
  ListCF<PriorTasks>? priorTasks;
  BooleanCF? ownSmartphone;
  BooleanCF? getPhoneForJob;
  BooleanCF? usedGoogleMaps;
  CF? glassBreak;
  CF? lateAndCustomerAngry;
  CF? customerRude;
  BooleanCF? willingToCleanPoojaRoom;
  BooleanCF? currentlyEmployed;
  CF? jobType;
  BooleanCF? willQuitJob;
  BooleanCF? workedBefore;
  CF? jobPreferredTime;
  CF? jobReachApproximation;
  CF? leaveCount;

  ///
  List<int>? willingClusters;
  BooleanCF? keepFasts;
  BooleanCF? tasksDuringFast;
  ListCF<LanguageProficiency>? languageProficiency;
  ListCF<String>? jobChangeReasons;
  ListCF<String>? vehiclesUsed;
  CF? yearsDivorced;
  NumberRangeCF? ageOfYoungestChild;
  BooleanCF? willingToLearnEBike;

  RunnerOtherDetails({
    this.spouseOccupation,
    this.spouseMonthlyIncome,
    this.spouseApproval,
    this.spouseKnowAboutJob,
    this.stayWithInLaws,
    this.inLawsApproval,
    this.numberOfChildren,
    this.dobOfYoungestChild,
    this.stayWithParents,
    this.parentsApproval,
    // this.yearOfDivorce,
    ListCF<PriorJob>? priorJobs,
    this.lastDrawnSalary,
    ListCF<PlanToUseSalary>? planToUseSalary,
    this.religion,
    this.sect,
    this.height,
    this.weight,
    this.highestEducation,
    this.dietaryPreference,
    this.petPreference,
    this.filledItrLast2Years,
    this.availability,
    this.hoursAvailableToWork,
    this.availableStartTime,
    this.availableEndTime,
    this.agreedTnc,
    this.tellFamilyInFuture,
    this.canReadLanguages = const [],
    this.tshirtAllowed,
    this.familyOkWithCleaningJob,
    this.canCleanNonVegKitchen,
    this.willingToCleanHomeWithPets,
    this.willingToCleanBathrooms,
    this.priorTasks,
    this.ownSmartphone,
    this.getPhoneForJob,
    this.usedGoogleMaps,
    this.glassBreak,
    this.lateAndCustomerAngry,
    this.customerRude,
    this.willingToCleanPoojaRoom,
    this.currentlyEmployed,
    this.jobType,
    this.willQuitJob,
    this.workedBefore,
    this.jobPreferredTime,
    this.jobReachApproximation,
    this.leaveCount,
    this.willingClusters,
    this.keepFasts,
    this.tasksDuringFast,
    this.languageProficiency,
    this.jobChangeReasons,
    this.vehiclesUsed,
    this.yearsDivorced,
    this.ageOfYoungestChild,
    this.willingToLearnEBike,
  }) {
    this.priorJobs = priorJobs ?? ListCF<PriorJob>(value: []);
    this.planToUseSalary =
        planToUseSalary ?? ListCF<PlanToUseSalary>(value: []);
  }

  Map<String, dynamic> toMap() {
    return {
      'spouse_occupation': spouseOccupation?.value,
      'spouse_monthly_income': spouseMonthlyIncome?.value,
      'spouse_approval': spouseApproval,
      'spouse_know_about_job': spouseKnowAboutJob,
      'stay_with_in_laws': stayWithInLaws,
      'in_laws_approval': inLawsApproval,
      'no_of_children': numberOfChildren?.value,
      'dob_of_youngest_child': getStringFromDateTime(dobOfYoungestChild),
      'stay_with_parents': stayWithParents?.value,
      'parents_approval': parentsApproval?.value,
      // 'year_of_divorce': yearOfDivorce,
      'jobs_done_prior': priorJobs?.value?.map((e) => e.name).toList(),
      'last_drawn_salary': lastDrawnSalary,
      'plan_to_use_snabbit_salary':
          planToUseSalary?.value?.map((e) => e.name).toList(),
      'religion': religion?.name,
      'sect': sect?.name,
      'height': height?.value,
      'weight': weight?.value,
      'highest_education': highestEducation?.name,
      'dietary_preference': dietaryPreference?.value?.name,
      'pet_preference': petPreference?.value?.name,
      'filed_itr_last_two_years': filledItrLast2Years?.value,
      'availability': availability?.value,
      'hours_available_to_work': hoursAvailableToWork?.value,
      'available_start_time': availableStartTime?.value,
      'available_end_time': availableEndTime?.value,
      'agreed_tnc': agreedTnc,
      'tell_family_in_future': tellFamilyInFuture,
      'languages_can_read': canReadLanguages?.map((e) => e.name).toList(),
      'tshirt_allowed': tshirtAllowed?.value,
      'family_ok_with_cleaning_job': familyOkWithCleaningJob?.value,
      'can_clean_non_veg_kitchen': canCleanNonVegKitchen?.value,
      'willing_to_clean_home_with_pets': willingToCleanHomeWithPets?.value,
      'willing_to_clean_bathrooms': willingToCleanBathrooms?.value,
      'prior_tasks': priorTasks?.value?.map((e) => e.name).toList(),
      'own_smartphone': ownSmartphone?.value,
      'get_phone_for_job': getPhoneForJob?.value,
      'used_google_maps': usedGoogleMaps?.value,
      'glass_break': glassBreak?.value,
      'late_and_customer_angry': lateAndCustomerAngry?.value,
      'customer_rude': customerRude?.value,
      'willing_to_clean_pooja_room': willingToCleanPoojaRoom?.value,
      'currently_employed': currentlyEmployed?.value,
      'job_type': jobType?.value,
      'will_quit_job': willQuitJob?.value,
      'worked_before': workedBefore?.value,
      'job_preferred_time': jobPreferredTime?.value,
      'job_reach_approximation': jobReachApproximation?.value,
      'leave_count': leaveCount?.value,
      'willing_cluster_ids': willingClusters?.map((e) => e).toList(),
      'keep_fasts': keepFasts?.value,
      'can_perform_tasks_during_fasts': tasksDuringFast?.value,
      'language_proficiency':
          languageProficiency?.value?.map((e) => e.toMap()).toList(),
      'job_change_reasons': jobChangeReasons?.value?.map((e) => e).toList(),
      'vehicles_used': vehiclesUsed?.value?.map((e) => e).toList(),
      'years_divorced': yearsDivorced?.value,
      'age_of_youngest_child': ageOfYoungestChild?.value,
      'willing_to_learn_ebike': willingToLearnEBike?.value,
    };
  }

  factory RunnerOtherDetails.fromMap(Map<String, dynamic> map) {
    return RunnerOtherDetails(
      spouseOccupation: CF(
        value: map['spouse_occupation'],
        key: 'spouse_occupation',
        acceptedValues:
            GlobalState().appConfig?.getCriticalField('spouse_occupation'),
      ),
      spouseMonthlyIncome: CF(
        value: map['spouse_monthly_income'],
        key: 'spouse_monthly_income',
        acceptedValues:
            GlobalState().appConfig?.getCriticalField('spouse_monthly_income'),
      ),
      spouseApproval: map['spouse_approval'],
      spouseKnowAboutJob: map['spouse_know_about_job'],
      stayWithInLaws: map['stay_with_in_laws'],
      inLawsApproval: map['in_laws_approval'],
      numberOfChildren: CF(
          value: map['no_of_children'],
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('no_of_children'),
          key: 'no_of_children'),
      dobOfYoungestChild:
          getDateTimeFromServerString(map['dob_of_youngest_child']),
      stayWithParents: CF(
        value: map['stay_with_parents'],
        key: 'stay_with_parents',
        acceptedValues:
            GlobalState().appConfig?.getCriticalField('stay_with_parents'),
      ),
      parentsApproval: CF(
          value: map['parents_approval'],
          key: 'parents_approval',
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('parents_approval')),
      //TODO: REMOVE
      // yearOfDivorce:
      //     map['year_of_divorce'] != null ? map['year_of_divorce'] : null,
      priorJobs: ListCF<PriorJob>(
          value: (map['jobs_done_prior'] as List<dynamic>?)
                  ?.map((e) => getPriorJobFromString(e))
                  .where((job) => job != null)
                  .cast<PriorJob>()
                  .toList() ??
              [],
          key: 'jobs_done_prior',
          acceptedValues: (GlobalState()
                  .appConfig
                  ?.getCriticalField('jobs_done_prior') as List<dynamic>?)
              ?.map((e) => getPriorJobFromString(e))
              .where((job) => job != null)
              .cast<PriorJob>()
              .toList()),

      // map['jobs_done_prior']
      //         ?.map((e) => getPriorJobFromString(e))
      //         .where((priorJob) => priorJob != null)
      //         .toList() ??
      //     []

      lastDrawnSalary: map['last_drawn_salary'],
      planToUseSalary: ListCF<PlanToUseSalary>(
        value: (map['plan_to_use_snabbit_salary'] as List<dynamic>?)
                ?.map((e) => getPlanToUseSalaryFromString(e))
                .where((plan) => plan != null)
                .cast<PlanToUseSalary>()
                .toList() ??
            [],
        key: 'plan_to_use_snabbit_salary',
        acceptedValues: (GlobalState()
                    .appConfig
                    ?.getCriticalField('plan_to_use_snabbit_salary')
                as List<dynamic>?)
            ?.where((plan) => plan != null)
            .cast<PlanToUseSalary>()
            .toList(),
      ),

      // map['plan_to_use_snabbit_salary']
      //         ?.map((e) => getPlanToUseSalaryFromString(e ))
      //         .where((e) => e != null)
      //         .toList() ??
      //     []

      religion: getReligionFromString(map['religion']),
      sect: getSectFromString(map['sect']),
      height: NumberRangeCF(
        key: 'height',
        value: map['height'],
        acceptedValues: List<int>.from(
            GlobalState().appConfig?.getCriticalField('height') ?? []),
      ),
      weight: NumberRangeCF(
        value: map['weight'],
        key: 'weight',
        acceptedValues: List<int>.from(
            GlobalState().appConfig?.getCriticalField('weight') ?? []),
      ),
      highestEducation: getEducationFromString(map['highest_education']),
      dietaryPreference: CF<DietaryPreference>(
          value: getDietaryPreferenceFromString(map['dietary_preference']),
          key: 'dietary_preference',
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('dietary_preference')),
      petPreference: CF<PetPreference>(
          value: getPetPreferenceFromString(map['pet_preference']),
          key: 'pet_preference',
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('pet_preference')),
      filledItrLast2Years: CF(
        value: map['filed_itr_last_two_years'],
        key: 'filed_itr_last_two_years',
        acceptedValues: GlobalState()
            .appConfig
            ?.getCriticalField('filed_itr_last_two_years'),
      ),
      availability: CF(
        value: map['availability'],
        acceptedValues:
            GlobalState().appConfig?.getCriticalField('availability'),
        key: 'availability',
      ),
      hoursAvailableToWork: CF(
          key: 'hours_available_to_work',
          value: map['hours_available_to_work'],
          acceptedValues: GlobalState()
              .appConfig
              ?.getCriticalField('hours_available_to_work')),
      availableStartTime: CF(
          key: 'available_start_time',
          value: map['available_start_time'],
          acceptedValues: GlobalState()
              .appConfig
              ?.getCriticalField('available_start_time')),
      availableEndTime: CF(
          value: map['available_end_time'],
          key: 'available_end_time',
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('available_end_time')),
      agreedTnc: map['agreed_tnc'] != null ? map['agreed_tnc'] : null,
      tellFamilyInFuture: map['tell_family_in_future'] != null
          ? map['tell_family_in_future']
          : null,
      canReadLanguages: map['languages_can_read'] != null
          ? map['languages_can_read']
              .map((e) => getReadLevelLanguagesFromString(e))
              .where((e) => e != null)
              .cast<ReadLevelLanguages>()
              .toList()
          : [],
      tshirtAllowed: BooleanCF(
        value: map['tshirt_allowed'],
        key: 'tshirt_allowed',
        acceptedValue:
            GlobalState().appConfig?.getCriticalField('tshirt_allowed'),
      ),
      familyOkWithCleaningJob: BooleanCF(
          value: map['family_ok_with_cleaning_job'],
          key: 'family_ok_with_cleaning_job',
          acceptedValue: GlobalState()
              .appConfig
              ?.getCriticalField('family_ok_with_cleaning_job')),
      canCleanNonVegKitchen: BooleanCF(
          value: map['can_clean_non_veg_kitchen'],
          key: 'can_clean_non_veg_kitchen',
          acceptedValue: GlobalState()
              .appConfig
              ?.getCriticalField('can_clean_non_veg_kitchen')),
      willingToCleanHomeWithPets: BooleanCF(
          value: map['willing_to_clean_home_with_pets'],
          key: 'willing_to_clean_home_with_pets',
          acceptedValue: GlobalState()
              .appConfig
              ?.getCriticalField('willing_to_clean_home_with_pets')),
      willingToCleanBathrooms: BooleanCF(
          value: map['willing_to_clean_bathrooms'],
          key: 'willing_to_clean_bathrooms',
          acceptedValue: GlobalState()
              .appConfig
              ?.getCriticalField('willing_to_clean_bathrooms')),
      priorTasks: ListCF<PriorTasks>(
          key: 'prior_tasks',
          value: map['prior_tasks']
                  ?.map((e) => getPriorTasksFromString(e))
                  .where((task) => task != null)
                  .cast<PriorTasks>()
                  .toList() ??
              [],
          acceptedValues: GlobalState()
                  .appConfig
                  ?.getCriticalField('prior_tasks')
                  ?.map((e) => getPriorTasksFromString(e))
                  .where((task) => task != null)
                  .cast<PriorTasks>()
                  .toList() ??
              []),
      ownSmartphone: BooleanCF(
          value: map['own_smartphone'],
          key: 'own_smartphone',
          acceptedValue:
              GlobalState().appConfig?.getCriticalField('own_smartphone')),
      getPhoneForJob: BooleanCF(
          value: map['get_phone_for_job'],
          key: 'get_phone_for_job',
          acceptedValue:
              GlobalState().appConfig?.getCriticalField('get_phone_for_job')),
      usedGoogleMaps: BooleanCF(
          value: map['used_google_maps'],
          key: 'used_google_maps',
          acceptedValue:
              GlobalState().appConfig?.getCriticalField('used_google_maps')),
      glassBreak: CF(
          value: map['glass_break'],
          key: 'glass_break',
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('glass_break')),
      lateAndCustomerAngry: CF(
        value: map['late_and_customer_angry'],
        key: 'late_and_customer_angry',
        acceptedValues: GlobalState()
            .appConfig
            ?.getCriticalField('late_and_customer_angry'),
      ),
      customerRude: CF(
        value: map['customer_rude'],
        key: 'customer_rude',
        acceptedValues:
            GlobalState().appConfig?.getCriticalField('customer_rude'),
      ),
      willingToCleanPoojaRoom: BooleanCF(
          value: map['willing_to_clean_pooja_room'],
          key: 'willing_to_clean_pooja_room',
          acceptedValue: GlobalState()
              .appConfig
              ?.getCriticalField('willing_to_clean_pooja_room')),
      currentlyEmployed: BooleanCF(
          value: map['currently_employed'],
          key: 'currently_employed',
          acceptedValue:
              GlobalState().appConfig?.getCriticalField('currently_employed')),
      jobType: CF(
          value: map['job_type'],
          key: 'job_type',
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('job_type')),
      willQuitJob: BooleanCF(
          value: map['will_quit_job'],
          key: 'will_quit_job',
          acceptedValue:
              GlobalState().appConfig?.getCriticalField('will_quit_job')),
      workedBefore: BooleanCF(
          value: map['worked_before'],
          key: 'worked_before',
          acceptedValue:
              GlobalState().appConfig?.getCriticalField('worked_before')),
      jobPreferredTime: CF(
          value: map['job_preferred_time'],
          key: 'job_preferred_time',
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('job_preferred_time')),
      jobReachApproximation: CF(
        value: map['job_reach_approximation'],
        key: 'job_reach_approximation',
        acceptedValues: GlobalState()
            .appConfig
            ?.getCriticalField('job_reach_approximation'),
      ),
      leaveCount: CF(
          value: map['leave_count'],
          key: 'leave_count',
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('leave_count')),
      willingClusters:
          (map['willing_cluster_ids'] as List?)?.map((e) => e as int).toList(),
      keepFasts: BooleanCF(
          value: map['keep_fasts'],
          key: 'keep_fasts',
          acceptedValue:
              GlobalState().appConfig?.getCriticalField('keep_fasts')),
      tasksDuringFast: BooleanCF(
          value: map['can_perform_tasks_during_fasts'],
          key: 'can_perform_tasks_during_fasts',
          acceptedValue: GlobalState()
              .appConfig
              ?.getCriticalField('can_perform_tasks_during_fasts')),
      languageProficiency: ListCF(
        value: (map['language_proficiency'] as List<dynamic>?)
            ?.map((e) => LanguageProficiency.fromMap(e as Map<String, dynamic>))
            .toList(),
        key: 'language_proficiency',
        acceptedValues: (GlobalState()
                .appConfig
                ?.getCriticalField('language_proficiency') as List<dynamic>?)
            ?.map((e) => LanguageProficiency.fromMap(e as Map<String, dynamic>))
            .toList(),
      ),
      jobChangeReasons: ListCF(
        value: (map['job_change_reasons'] as List?)
            ?.map((e) => e as String)
            .toList(),
        key: 'job_change_reasons',
        acceptedValues: List<String>.from(
            GlobalState().appConfig?.getCriticalField('job_change_reasons') ??
                []),
      ),
      vehiclesUsed: ListCF(
        value:
            (map['vehicles_used'] as List?)?.map((e) => e as String).toList() ??
                [],
        key: 'vehicles_used',
        acceptedValues: List<String>.from(
            GlobalState().appConfig?.getCriticalField('vehicles_used') ?? []),
      ),
      yearsDivorced: CF(
          value: map['years_divorced'],
          key: 'years_divorced',
          acceptedValues:
              GlobalState().appConfig?.getCriticalField('years_divorced')),
      ageOfYoungestChild: NumberRangeCF(
          value: map['age_of_youngest_child'],
          acceptedValues: List<int>.from(GlobalState()
                  .appConfig
                  ?.getCriticalField('age_of_youngest_child') ??
              []),
          key: 'age_of_youngest_child'),
      willingToLearnEBike: BooleanCF(
          value: map['willing_to_learn_ebike'],
          acceptedValue: GlobalState()
              .appConfig
              ?.getCriticalField('willing_to_learn_ebike'),
          key: 'willing_to_learn_ebike'),
    );
  }
}

class RunnerIntegrityTestAnswers {
  IntegrityTest question;
  AnswerOption answer;

  RunnerIntegrityTestAnswers({
    required this.question,
    required this.answer,
  });

  Map<String, dynamic> toMap() {
    return {
      'question_id': question.id,
      'option_id': answer.id,
    };
  }

  factory RunnerIntegrityTestAnswers.fromMap(Map<String, dynamic> map) {
    return RunnerIntegrityTestAnswers(
      question: IntegrityTest.fromMap(map['question']),
      answer: AnswerOption.fromMap(map['option']),
    );
  }
}

class RunnerAppConfig {
  PayoutConfig? payoutConfig;
  bool? isWashroomFinderEnabled;
  bool? isMerchStoreEnabled;
  WebViewUrls? webViewUrls;
  // Per-runner Android force-update floor (null unless targeted at this runner).
  int? minAndroidVersion;
  int? skipAndroidVersion;

  RunnerAppConfig({
    this.payoutConfig,
    this.isWashroomFinderEnabled,
    this.isMerchStoreEnabled,
    this.webViewUrls,
    this.minAndroidVersion,
    this.skipAndroidVersion,
  });

  factory RunnerAppConfig.fromMap(Map<String, dynamic> data) {
    return RunnerAppConfig(
      payoutConfig: PayoutConfig.fromMap(data['payroll_config']),
      isWashroomFinderEnabled: data['is_washroom_finder_enabled'],
      isMerchStoreEnabled: data['is_merch_store_enabled'],
      webViewUrls: data['web_views'] != null
          ? WebViewUrls.fromMap(data['web_views'])
          : null,
      minAndroidVersion: data['min_android_version'],
      skipAndroidVersion: data['skip_android_version'],
    );
  }
}

class WebViewUrls {
  String? seva;
  String? merchStore;

  WebViewUrls({
    this.seva,
    this.merchStore,
  });

  factory WebViewUrls.fromMap(Map<String, dynamic> data) {
    return WebViewUrls(
      seva: data['seva'],
      merchStore: data['merch_store'],
    );
  }
}

class PayoutConfig {
  bool? showPayout;
  bool? showEarlyPayout;
  bool? showTransactionHistory;
  bool? showDailyPayout;
  bool? showMonthlyPayout;
  int? fpPenalty;
  int? noShowPenalty;
  bool? showRatingDeductionThreshold;
  bool? showRatingIncentiveThreshold;

  PayoutConfig({
    this.showPayout,
    this.showEarlyPayout,
    this.showTransactionHistory,
    this.showDailyPayout,
    this.showMonthlyPayout,
    this.fpPenalty,
    this.noShowPenalty,
    this.showRatingDeductionThreshold,
    this.showRatingIncentiveThreshold,
  });

  factory PayoutConfig.fromMap(Map<String, dynamic> data) {
    return PayoutConfig(
      showPayout: data['show_overall'],
      showEarlyPayout: data['show_early_payout'],
      showTransactionHistory: data['show_transaction_history'],
      showDailyPayout: data['show_daily'],
      showMonthlyPayout: data['show_monthly'],
      fpPenalty: anyValueToInt(data['fp_penalty']),
      noShowPenalty: anyValueToInt(data['no_show_penalty']),
      showRatingDeductionThreshold:
          data['show_rating_deduction_threshold'] ?? false,
      showRatingIncentiveThreshold:
          data['show_rating_incentive_threshold'] ?? false,
    );
  }
}

class RegistrationStep {
  /// Mapped Flutter route from [RunnerRegistrationStep.getStepRouteName].
  String? step;

  /// Backend enum (e.g. `CITY_SELECTION`) before route mapping.
  String? rawStep;
  int? currentValue;
  int? total;

  RegistrationStep({
    this.step,
    this.rawStep,
    this.currentValue,
    this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'step': rawStep ?? step,
      'current_value': currentValue,
      'total': total,
    };
  }

  factory RegistrationStep.fromMap(Map<String, dynamic> data) {
    final raw = data['step']?.toString();
    return RegistrationStep(
      rawStep: raw,
      step: raw != null ? RunnerRegistrationStep.getStepRouteName(raw) : null,
      currentValue: data['current_value'],
      total: data['total'],
    );
  }
}

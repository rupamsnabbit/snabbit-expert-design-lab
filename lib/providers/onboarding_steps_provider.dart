import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/bank_verification_model.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/pages/signup/aadhaar_details.dart';
import 'package:snabbit_runner/pages/signup/aadhaar_number_updater.dart';
import 'package:snabbit_runner/pages/signup/aadhaar_validator.dart';
import 'package:snabbit_runner/pages/signup/bank_details.dart';
import 'package:snabbit_runner/pages/signup/location_change_v2.dart';
import 'package:snabbit_runner/pages/signup/onboarding_screen.dart';
import 'package:snabbit_runner/pages/signup/pan_number_updater.dart';
import 'package:snabbit_runner/pages/signup/review/personal_details_review_v3.dart';
import 'package:snabbit_runner/pages/signup/onboarding_v2/onboarding_multiple_questions_screen.dart';
import 'package:snabbit_runner/pages/signup/onboarding_v2/onboarding_single_question_screen.dart';
import 'package:snabbit_runner/pages/signup/training_progress.dart';
import 'package:snabbit_runner/pages/signup/training_slots.dart';
import 'package:snabbit_runner/pages/signup/upload_aadhaar_photos.dart';
import 'package:snabbit_runner/pages/signup/voter_id_updater.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/models/onboarding_module.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_helper_utils.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/server_requests/onboarding_steps_services.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/utils/navigation_utils.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_failed_view.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_status_view.dart';

class OnboardingStepsProvider with ChangeNotifier {
  ModuleGroupResponse? _onboardingModules;
  OnboardingQuestionGroup? _currentQuestionsData;
  OnboardingQuestionResponse? _onboardingQuestionResponse;
  String? error;
  CustomError? onboardingQAError;
  Response? onboardingScreenErrorResponse;
  bool loading = false;
  OnboardingStatusData? _onboardingStatusData;
  OnboardingFailedData? _onboardingFailedData;
  PayoutOption? _selectedPayoutOption;
  BankVerificationResponse? _bankVerificationResponse;
  String? _currentUpiId;

  /// Whether the active onboarding session was launched from the web hub
  /// (`AppWebViewPage`) rather than the native [OnboardingScreen]. When true,
  /// returning to the module hub (`page_type == "module"`) pops back to the
  /// live webview instead of pushing the native hub. Set per-session by
  /// [getInitialQuestion]; defaults to false so the native flow is unchanged.
  bool _launchedFromWebHub = false;

  OnboardingStatusData? get onboardingStatusData => _onboardingStatusData;

  OnboardingFailedData? get onboardingFailedData => _onboardingFailedData;

  PayoutOption? get selectedPayoutOption => _selectedPayoutOption;

  BankVerificationResponse? get bankVerificationResponse =>
      _bankVerificationResponse;

  String? get currentUpiId => _currentUpiId;

  ModuleGroupResponse? get onboardingModules => _onboardingModules;

  OnboardingQuestionGroup? get currentQuestionsData => _currentQuestionsData;

  OnboardingQuestionResponse? get onboardingQuestionResponse =>
      _onboardingQuestionResponse;

  set onboardingModule(ModuleGroupResponse? onboardingModules) {
    _onboardingModules = onboardingModules;
    notifyListeners();
  }

  set selectedPayoutOption(PayoutOption? option) {
    _selectedPayoutOption = option;
    notifyListeners();
  }

  bool get _isTrainingV2Enabled => RemoteConfigHelperUtils.isTrainingV2Enabled;

  Future<void> setupOnboardingScreen() async {
    // The native onboarding hub is (re)loading — definitively native mode.
    // Clear any stale web-launch flag from a prior web-launched session so
    // native step completions push the native hub rather than popping to a
    // (possibly absent) AppWebViewPage.
    _launchedFromWebHub = false;
    try {
      loading = true;
      notifyListeners();
      Response? response = await OnboardingStepsServices.getSteps();
      loading = false;
      notifyListeners();
      if (response?.statusCode == 200) {
        final data = response?.data;
        if (data is Map<String, dynamic>) {
          final pageType =
              OnboardingPageType.fromString(data['page_type']?.toString());
          if (pageType == OnboardingPageType.failed) {
            // Handle failed response
            final screen = _handleOnboardingResponseData(data);
            if (screen != null &&
                GlobalState().navigatorKey.currentContext != null) {
              Navigator.of(GlobalState().navigatorKey.currentContext!)
                  .pushReplacementNamed(screen);
            }
          } else {
            // Handle module response (default behavior)
            onboardingModule = ModuleGroupResponse.fromJson(data);
          }
        } else {
          onboardingModule = ModuleGroupResponse.fromJson(data);
        }
      } else {
        onboardingScreenErrorResponse = response;
        String error;
        try {
          error = response?.data['errors'][0]['message'];
        } catch (e) {
          error = "Server error - ${response?.statusCode}";
        }
        showSnackbar(GlobalState().navigatorKey.currentContext!, error);
      }
    } catch (e) {
      // DO NOTHING
    }
  }

  Future<String?> getInitialQuestion({
    required BuildContext context,
    required int moduleId,
    bool launchedFromWebHub = false,
  }) async {
    // Record where this session was launched from so completion / back-out
    // returns to the right hub. Native callers omit this (stay false).
    _launchedFromWebHub = launchedFromWebHub;
    loading = true;
    notifyListeners();

    try {
      final response = await OnboardingStepsServices.getQuestion(
        moduleId: moduleId.toString(),
      );

      if (response == null) {
        error = "No response from server";
        return null;
      }

      if (response.statusCode == 200) {
        error = null;
        onboardingQAError = null;

        final screen = _handleOnboardingResponseData(response.data);

        if (screen == null) {
          error = "Invalid response data";
          return null;
        }

        return screen;
      } else {
        error = response.data?['errors']?[0]?['message'];
        if (context.mounted) {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              onboardingQAError = responseError.getFirstError();
            },
          );
        }
        return null;
      }
    } catch (e) {
      error = "Something went wrong: $e";
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> submitAnswerAndProceed({
    required BuildContext context,
    required Map<String, dynamic>? data,
    Function()? onSuccess,
    Function(CustomError)? onError,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final response = await OnboardingStepsServices.submitAnswer(data: data);

      if (response == null) {
        error = "No response from server";
        return;
      }

      if (response.statusCode == 200) {
        error = null;
        onboardingQAError = null;

        final screen = _handleOnboardingResponseData(response.data);

        if (!context.mounted) return;

        onSuccess?.call();

        if (screen != null) {
          _navigateToOnboardingScreen(context, screen);
        } else {
          showSnackbar(context, "No next screen defined for response");
        }
      } else {
        if (context.mounted) {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              onboardingQAError = responseError.getFirstError();
              error = onboardingQAError?.title;
              onError?.call(onboardingQAError!);
            },
          );
        } else {
          error = "Unhandled response error - ${response.statusCode}";
        }
      }
    } catch (e) {
      error = "Something went wrong: $e";
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> goBackToPreviousQuestion(
    BuildContext context,
    int moduleId,
  ) async {
    loading = true;
    notifyListeners();

    try {
      final response = await OnboardingStepsServices.goToPreviousQuestion(
        moduleId: moduleId.toString(),
      );

      if (response == null) {
        showSnackbar(context, "No response from server");
        return;
      }

      if (response.statusCode == 200) {
        final data = response.data;
        String? screen;
        Object? args;

        if (data["page_type"] == "module") {
          onboardingModule = ModuleGroupResponse.fromJson(data);
          screen = OnboardingScreen.routeName;
        } else {
          _onboardingQuestionResponse =
              OnboardingQuestionResponse.fromJson(data);
          _currentQuestionsData =
              _onboardingQuestionResponse?.onboardingQuestionGroup;

          screen = getCurrentScreen(
            _currentQuestionsData?.groupKey,
            _currentQuestionsData?.displayMode,
          );
          args = getWebViewArgs(
            _currentQuestionsData?.groupKey,
            _currentQuestionsData?.displayMode,
          );
        }

        if (context.mounted && screen != null) {
          _navigateToOnboardingScreen(context, screen, args: args);
        }
      } else {
        if (!context.mounted) return;

        ErrorHandler.handleResponseError(
          response: response,
          context: context,
          onError: (context, responseError) {
            final error = responseError.getFirstError();

            if (error?.errorMessageCode == "NO_PREVIOUS_QUESTION") {
              Navigator.of(context).pop();
            } else {
              showSnackbar(
                context,
                error?.errorMessageCode ?? "An error occurred",
              );
            }
          },
        );
      }
    } catch (e) {
      error = "Something went wrong: $e";
      if (context.mounted) {
        showSnackbar(context, error!);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> verifyPan({
    required BuildContext context,
    required Map<String, dynamic> data,
    Function()? onSuccess,
    Function(CustomError)? onError,
    bool navigateOnSuccess = true,
  }) async {
    await _handleOnboardingRequest(
      context: context,
      request: () => OnboardingStepsServices.verifyPan(data: data),
      onSuccess: onSuccess,
      onError: onError,
      navigateOnSuccess: navigateOnSuccess,
    );
  }

  Future<void> uploadAadhaar({
    required BuildContext context,
    required FormData data,
    Function()? onSuccess,
    Function(CustomError)? onError,
    bool navigateOnSuccess = true,
  }) async {
    await _handleOnboardingRequest(
      context: context,
      request: () => OnboardingStepsServices.uploadAadhaar(data: data),
      onSuccess: onSuccess,
      onError: onError,
      navigateOnSuccess: navigateOnSuccess,
    );
  }

  Future<void> verifyVoterId({
    required BuildContext context,
    required Map<String, dynamic> data,
    Function()? onSuccess,
    Function(CustomError)? onError,
    bool navigateOnSuccess = true,
  }) async {
    await _handleOnboardingRequest(
      context: context,
      request: () => OnboardingStepsServices.verifyVoterId(data: data),
      onSuccess: onSuccess,
      onError: onError,
      navigateOnSuccess: navigateOnSuccess,
    );
  }

  Future<void> performAction({
    required BuildContext context,
    required Map<String, dynamic> data,
    Function()? onSuccess,
    Function(CustomError)? onError,
    bool navigateOnSuccess = true,
  }) async {
    await _handleOnboardingRequest(
      context: context,
      request: () => OnboardingStepsServices.performAction(data: data),
      onSuccess: onSuccess,
      onError: onError,
      navigateOnSuccess: navigateOnSuccess,
    );
  }

  Future<void> verifyBankOrUpi({
    required BuildContext context,
    required Map<String, dynamic> data,
    Function()? onSuccess,
    Function(CustomError)? onError,
  }) async {
    loading = true;
    _currentUpiId = data['upi_id'];
    notifyListeners();

    try {
      final response =
          await OnboardingStepsServices.verifyBankOrUpi(data: data);

      if (response == null) {
        error = "No response from server";
        if (onError != null) {
          onError(CustomError(
            title: "Network Error",
            message: "Unable to connect to server",
            errorMessageCode: "NETWORK_ERROR",
          ));
        }
        return;
      }

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('errors') &&
            responseData['errors'] is List &&
            responseData['errors'].isNotEmpty) {
          // Handle custom error in success response
          final errorData = responseData['errors'][0];
          final customError = CustomError(
            title: errorData['title'] ?? "Verification Error",
            message: errorData['message'] ?? "Verification failed",
            errorMessageCode: errorData['code'] ?? "VALIDATION_ERROR",
          );
          error = customError.title;
          onboardingQAError = customError;
          if (onError != null) {
            onError(customError);
          }
        } else {
          // Success - verified instrument details
          error = null;
          onboardingQAError = null;

          // Store the verification response
          _bankVerificationResponse =
              BankVerificationResponse.fromJson(responseData);
          onSuccess?.call();

          // Navigation will be handled by the calling screen based on status
        }
      } else {
        // Handle HTTP error responses
        if (context.mounted) {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              onboardingQAError = responseError.getFirstError();
              error = onboardingQAError?.title;
              if (onError != null) {
                onError(onboardingQAError!);
              }
            },
          );
        } else {
          error = "Unhandled response error - ${response.statusCode}";
        }
      }
    } catch (e) {
      error = "Something went wrong: $e";
      if (onError != null) {
        onError(CustomError(
          title: "Unexpected Error",
          message: "An unexpected error occurred",
          errorMessageCode: "UNEXPECTED_ERROR",
        ));
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> verifyBankOtp({
    required BuildContext context,
    required Map<String, dynamic> data,
    Function()? onSuccess,
    Function(CustomError)? onError,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final response = await OnboardingStepsServices.verifyBankOtp(data: data);

      if (response == null) {
        error = "No response from server";
        if (onError != null) {
          onError(CustomError(
            title: "Network Error",
            message: "Unable to connect to server",
            errorMessageCode: "NETWORK_ERROR",
          ));
        }
        return;
      }

      if (response.statusCode == 200) {
        // Check if response contains errors (custom error object in success response)
        final responseData = response.data;
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('errors') &&
            responseData['errors'] is List &&
            responseData['errors'].isNotEmpty) {
          // Handle custom error in success response
          final errorData = responseData['errors'][0];
          final customError = CustomError(
            title: errorData['title'] ?? "Verification Error",
            message: errorData['message'] ?? "OTP verification failed",
            errorMessageCode: errorData['code'] ?? "VERIFICATION_ERROR",
          );
          error = customError.title;
          onboardingQAError = customError;
          if (onError != null) {
            onError(customError);
          }
        } else {
          // Success - OTP verified
          error = null;
          onboardingQAError = null;
          onSuccess?.call();
        }
      } else {
        // Handle HTTP error responses
        if (context.mounted) {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              onboardingQAError = responseError.getFirstError();
              error = onboardingQAError?.title;
              if (onError != null) {
                onError(onboardingQAError!);
              }
            },
          );
        } else {
          error = "Unhandled response error - ${response.statusCode}";
        }
      }
    } catch (e) {
      error = "Something went wrong: $e";
      if (onError != null) {
        onError(CustomError(
          title: "Unexpected Error",
          message: "An unexpected error occurred",
          errorMessageCode: "UNEXPECTED_ERROR",
        ));
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void notifyUserListeners() {
    notifyListeners();
  }

  Future<void> _handleOnboardingRequest({
    required BuildContext context,
    required Future<Response?> Function() request,
    Function()? onSuccess,
    Function(CustomError)? onError,
    bool navigateOnSuccess = true,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final response = await request();

      if (response == null) {
        error = "No response from server";
        return;
      }

      if (response.statusCode == 200) {
        error = null;
        onboardingQAError = null;

        final screen = _handleOnboardingResponseData(response.data);

        if (!context.mounted) {
          return;
        }

        onSuccess?.call();

        if (navigateOnSuccess && screen != null) {
          _navigateToOnboardingScreen(context, screen);
        }
      } else {
        if (context.mounted) {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              onboardingQAError = responseError.getFirstError();
              error = onboardingQAError?.title;
              if (onboardingQAError != null) {
                onError?.call(onboardingQAError!);
              }
            },
          );
        } else {
          error = "Unhandled response error - ${response.statusCode}";
        }
      }
    } catch (e) {
      error = "Something went wrong: $e";
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Navigates to a screen resolved by [_handleOnboardingResponseData] /
  /// [getCurrentScreen].
  ///
  /// For a web-launched session ([_launchedFromWebHub]) that is returning to
  /// the module hub ([OnboardingScreen]), this pops back to the live
  /// [AppWebViewPage] (preserving its state) instead of pushing the native
  /// hub — so the web onboarding flow resumes where it left off. The web hub
  /// refreshes its own state when it regains visibility.
  ///
  /// Every other case (native sessions, and terminal `status`/`failed` views)
  /// keeps the original `pushReplacementNamed` behavior, so the native flow is
  /// unchanged.
  void _navigateToOnboardingScreen(
    BuildContext context,
    String screen, {
    Object? args,
  }) {
    // When v2 is enabled the onboarding hub IS the training webview, so a
    // request to show the legacy native hub ([OnboardingScreen]) must instead
    // open the web hub. Uses the canonical openTrainingWebView(replace: true)
    // which does pushNamedAndRemoveUntil anchored to SelectLanguageV2/root —
    // safe whether or not AppWebViewPage is still on the stack (it may have
    // been removed by a closeBehavior:"replace" navigate from the web hub).
    if (screen == OnboardingScreen.routeName &&
        (_launchedFromWebHub || _isTrainingV2Enabled)) {
      NavigationUtils.openTrainingWebView(context: context, replace: true);
      _launchedFromWebHub = false;
      return;
    }
    Navigator.of(context).pushReplacementNamed(screen, arguments: args);
  }

  String? _handleOnboardingResponseData(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final pageType =
        OnboardingPageType.fromString(data['page_type']?.toString());

    switch (pageType) {
      case OnboardingPageType.module:
        onboardingModule = ModuleGroupResponse.fromJson(data);
        return OnboardingScreen.routeName;
      case OnboardingPageType.status:
        _onboardingStatusData = OnboardingStatusData.fromJson(data);
        return OnboardingStatusView.routeName;
      case OnboardingPageType.failed:
        _onboardingFailedData = OnboardingFailedData.fromJson(data);
        return OnboardingFailedView.routeName;
      case OnboardingPageType.question:
        _onboardingQuestionResponse = OnboardingQuestionResponse.fromJson(data);
        _currentQuestionsData =
            _onboardingQuestionResponse?.onboardingQuestionGroup;

        return getCurrentScreen(
          _currentQuestionsData?.groupKey,
          _currentQuestionsData?.displayMode,
        );

      default:
        return null;
    }
  }

  Future<void> submitPerfiosValidationResponse({
    required BuildContext context,
    required String jsonString,
    required int sessionId,
    required int questionId,
    Function()? onSuccess,
    Function(String error)? onError,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final response = await OnboardingStepsServices.submitPerfiosResponse(
        jsonString: jsonString,
        sessionId: sessionId,
        questionId: questionId,
      );

      if (response == null) {
        error = "No response from server";
        if (onError != null) {
          onError(error!);
        }
        return;
      }

      if (response.statusCode == 200) {
        error = null;
        onboardingQAError = null;

        final screen = _handleOnboardingResponseData(response.data);

        if (!context.mounted) return;

        onSuccess?.call();

        if (screen != null) {
          _navigateToOnboardingScreen(context, screen);
        } else {
          showSnackbar(context, "Verification complete");
        }
      } else {
        if (context.mounted) {
          ErrorHandler.handleResponseError(
            response: response,
            context: context,
            onError: (context, responseError) {
              onboardingQAError = responseError.getFirstError();
              error = onboardingQAError?.title;
              if (onError != null) {
                onError(error ?? "An error occurred");
              }
            },
          );
        } else {
          error = "Unhandled response error - ${response.statusCode}";
          if (onError != null) {
            onError(error!);
          }
        }
      }
    } catch (e) {
      error = "Something went wrong: $e";
      if (onError != null) {
        onError(error!);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  String? getCurrentScreen(
      OnboardingStepGroupKeys? groupKey, DisplayMode? displayMode) {
    switch (groupKey) {
      case OnboardingStepGroupKeys.bankDetails:
        return BankDetails.routeName;
      case OnboardingStepGroupKeys.aadhaarDetails:
        return AadhaarDetails.routeName;
      case OnboardingStepGroupKeys.aadhaarOtp:
        return AadhaarValidator.routeName;
      case OnboardingStepGroupKeys.locationInfo:
        return LocationChangeV2.routeName;
      case OnboardingStepGroupKeys.personalDetailsReview:
        return PersonalDetailsReviewV3.routeName;
      case OnboardingStepGroupKeys.panVerification:
        return PanNumberUpdater.routeName;
      case OnboardingStepGroupKeys.aadhaarUpload:
        return UploadAadhaarPhotos.routeName;
      case OnboardingStepGroupKeys.voterId:
        return VoterIDUpdater.routeName;
      case OnboardingStepGroupKeys.aadhaarNumber:
        return AadhaarNumberUpdater.routeName;
      case OnboardingStepGroupKeys.trainingSlots:
        return TrainingSlots.routeName;
      case OnboardingStepGroupKeys.trainingProgress:
        return _isTrainingV2Enabled
            ? AppWebViewPage.routeName
            : TrainingProgress.routeName;
      default:
        if (displayMode == DisplayMode.multimedia) {
          return OnboardingSingleQuestionScreen.routeName;
        } else if (displayMode == DisplayMode.form) {
          return OnboardingMultipleQuestionsScreen.routeName;
        }
        return null;
    }
  }

  WebViewArgs? getWebViewArgs(
      OnboardingStepGroupKeys? groupKey, DisplayMode? displayMode) {
    switch (groupKey) {
      case OnboardingStepGroupKeys.trainingProgress:
        if (_isTrainingV2Enabled){
          return WebViewArgs(
            url: buildWebviewUrl(WebviewRoutes.training),
            title: "Training Progress",
            fetchLocation: true,
          );
        }
        return null;
      default:
        return null;
    }
  }
}

enum OnboardingStepGroupKeys {
  bankDetails,
  aadhaarDetails,
  locationInfo,
  personalDetailsReview,
  panVerification,
  aadhaarUpload,
  aadhaarOtp,
  aadhaarNumber,
  voterId,
  trainingSlots,
  trainingProgress,
  manualEntry;

  static OnboardingStepGroupKeys? fromString(String? key) {
    switch (key?.toLowerCase()) {
      case "bank_details":
        return OnboardingStepGroupKeys.bankDetails;
      case "aadhaar_entry":
        return OnboardingStepGroupKeys.aadhaarDetails;
      case "aadhaar_otp":
        return OnboardingStepGroupKeys.aadhaarOtp;
      case "location_info":
        return OnboardingStepGroupKeys.locationInfo;
      case "personal_details_review":
        return OnboardingStepGroupKeys.personalDetailsReview;
      case "pan_verification":
        return OnboardingStepGroupKeys.panVerification;
      case "aadhaar_upload":
        return OnboardingStepGroupKeys.aadhaarUpload;
      case "aadhaar_number":
        return OnboardingStepGroupKeys.aadhaarNumber;
      case "voter_id":
        return OnboardingStepGroupKeys.voterId;
      case "training_slots":
        return OnboardingStepGroupKeys.trainingSlots;
      case "training_progress":
        return OnboardingStepGroupKeys.trainingProgress;
      case "manual_entry":
        return OnboardingStepGroupKeys.manualEntry;
      default:
        return null;
    }
  }
}

enum DisplayMode {
  multimedia,
  form;

  static DisplayMode? fromString(String? mode) {
    switch (mode?.toLowerCase()) {
      case "multimedia":
        return DisplayMode.multimedia;
      case "form":
        return DisplayMode.form;
      default:
        return null;
    }
  }
}

enum OnboardingPageType {
  module,
  question,
  status,
  failed;

  static OnboardingPageType? fromString(String? pageType) {
    switch (pageType?.toLowerCase()) {
      case "module":
        return OnboardingPageType.module;
      case "question":
        return OnboardingPageType.question;
      case "status":
        return OnboardingPageType.status;
      case "failed":
        return OnboardingPageType.failed;
      default:
        return null;
    }
  }
}

enum PayoutOption {
  upi,
  bankDetails;

  static PayoutOption? fromString(String? option) {
    switch (option?.toLowerCase()) {
      case "upi":
        return PayoutOption.upi;
      case "bank_details":
        return PayoutOption.bankDetails;
      default:
        return null;
    }
  }

  String toDisplayString() {
    switch (this) {
      case PayoutOption.upi:
        return "UPI";
      case PayoutOption.bankDetails:
        return "Bank Details";
    }
  }
}

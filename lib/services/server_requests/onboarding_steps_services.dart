import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';

class OnboardingStepsServices {
  // Fetch onboarding steps
  static Future<Response?> getSteps({Map<String, dynamic>? headers}) async {
    try {
      final response = await HttpService().get(
        GlobalState().onboardingUrlServerPath("api/v1/onboarding"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> getQuestion({
    required String moduleId,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().onboardingUrlServerPath(
            "api/v1/onboarding/next_questions?module_id=$moduleId"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> submitAnswer({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().onboardingUrlServerPath("api/v1/onboarding/responses"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> goToPreviousQuestion({
    required String moduleId,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().onboardingUrlServerPath(
            "api/v1/onboarding/previous_questions?module_id=$moduleId"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> verifyPan({
    Map<String, dynamic>? headers,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().onboardingUrlServerPath("api/v1/verification/pan/verify"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> updatePan({
    Map<String, dynamic>? headers,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().onboardingUrlServerPath("api/v1/verification/pan/update"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> uploadAadhaar({
    Map<String, dynamic>? headers,
    required FormData data,
  }) async {
    try {
      final response = await HttpService().postDocs(
        GlobalState()
            .onboardingUrlServerPath("api/v1/verification/aadhaar/upload"),
        formData: data,
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> verifyVoterId({
    Map<String, dynamic>? headers,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState()
            .onboardingUrlServerPath("api/v1/verification/voter_id/verify"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> performAction({
    Map<String, dynamic>? headers,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState().onboardingUrlServerPath("api/v1/verification/actions"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> submitPerfiosResponse({
    required String jsonString,
    required int sessionId,
    required int questionId,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final Map<String, dynamic> perfiosData = jsonDecode(jsonString);
      final payload = {
        "perfios_response": perfiosData,
        "session_id": sessionId,
        "question_id": questionId,
      };

      final response = await HttpService().post(
        GlobalState()
            .onboardingUrlServerPath("api/v1/verification/aadhaar/verify"),
        headers: headers ?? {},
        data: payload,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> verifyBankOrUpi({
    Map<String, dynamic>? headers,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState()
            .onboardingUrlServerPath("api/v1/verification/bank/verify"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<Response?> verifyBankOtp({
    Map<String, dynamic>? headers,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await HttpService().post(
        GlobalState()
            .onboardingUrlServerPath("api/v1/verification/bank/verify_otp"),
        headers: headers ?? {},
        data: data,
      );
      return response;
    } catch (e) {
      return null;
    }
  }
}

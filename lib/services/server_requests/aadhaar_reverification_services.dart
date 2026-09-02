import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Network layer for the stateless Aadhaar re-KYC endpoint
/// `POST /api/v1/verification/aadhaar/update`.
///
/// Mirrors `OnboardingStepsServices.submitPerfiosResponse` but without any
/// session/question — the raw Perfios result is posted as-is.
class AadhaarReverificationServices {
  AadhaarReverificationServices._();

  /// Posts the raw Perfios result. [perfiosJson] is the unmodified string from
  /// the Perfios `onShutdown` callback. Returns the [Response] (including
  /// non-200s, which the caller branches on) or `null` if the request could not
  /// be made / the body could not be parsed.
  static Future<Response?> submitAadhaarUpdate({
    required String perfiosJson,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final Map<String, dynamic> perfiosData = jsonDecode(perfiosJson);
      final payload = {
        "perfios_response": perfiosData,
      };

      final response = await HttpService().post(
        GlobalState()
            .onboardingUrlServerPath("api/v1/verification/aadhaar/update"),
        headers: headers ?? {},
        data: payload,
      );
      return response;
    } catch (e, st) {
      MonitoringServiceHelper.reportError(
        'AADHAAR_REKYC_SUBMIT_FAILED',
        {'error': e.toString()},
        st.toString(),
      );
      return null;
    }
  }

  /// Exchanges the Perfios credentials for an OAuth token and returns the
  /// Perfios `aadhaar-xml` SSP URL to load in the webview, or `null` on failure.
  ///
  /// Uses a raw [Dio] (NOT [HttpService]) on purpose: this hits Perfios's
  /// external OAuth endpoint, not the Snabbit backend. [HttpService] would
  /// attach the runner's Snabbit bearer token + version headers and trigger a
  /// global logout on a 401 — none of which is correct for Perfios. (Mirrors
  /// the onboarding `AadhaarValidator` Perfios call.)
  static Future<String?> fetchPerfiosAadhaarXmlUrl({
    required String username,
    required String password,
    required String organizationId,
  }) async {
    try {
      // Bounded timeouts so a stalled Perfios token call can't hang the flow.
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(minutes: 1),
        receiveTimeout: const Duration(minutes: 1),
      ));
      final response = await dio.post(
        "https://hub.perfios.ai/oauth2/token",
        options: Options(headers: {
          "username": username,
          "password": password,
          "x-organization-id": organizationId,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.data);
        final authorizationToken = data?["access_token"] ?? "";
        if (authorizationToken.isNotEmpty) {
          final url =
              "https://hub.perfios.ai/ssp/aadhaar-xml/?authorization=$authorizationToken&x-organization-id=$organizationId";
          // Logs the full URL (incl. the short-lived Perfios authorization
          // token) — Perfios devs need it for debugging; matches the onboarding
          // AadhaarValidator's PERFIOS_URL_CREATION_SUCCESSFUL log.
          MonitoringServiceHelper.logDebug(
            'AADHAAR_REKYC_PERFIOS_URL_CREATED',
            {'env': GlobalState().currentEnv.name, 'url': url},
          );
          return url;
        }
        MonitoringServiceHelper.logDebug(
          'AADHAAR_REKYC_PERFIOS_TOKEN_INVALID',
          {'env': GlobalState().currentEnv.name},
        );
      } else {
        MonitoringServiceHelper.logDebug(
          'AADHAAR_REKYC_PERFIOS_TOKEN_FAILED',
          {
            'env': GlobalState().currentEnv.name,
            'response_status_code': response.statusCode,
            'response_status_message': response.statusMessage,
            'response_data': response.data,
          },
        );
      }
    } catch (e, st) {
      MonitoringServiceHelper.reportError(
        'AADHAAR_REKYC_PERFIOS_URL_FAILED',
        {'env': GlobalState().currentEnv.name, 'error': e.toString()},
        st.toString(),
      );
    }
    return null;
  }
}

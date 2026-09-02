import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:url_launcher/url_launcher.dart';

class CallingService {
  static Future<Response?> initiateCall({
    required String phoneNumber,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await HttpService().post(
          GlobalState().serverPath("api/v1/runners/phone_call/$phoneNumber"),
          headers: headers ?? {});
      return response;
    } catch (e) {
      return null;
    }
  }
}

class CallUtils {
  static Future<void> handleCallInitiation({
    required String phoneNumber,
    BuildContext? context,
    required String callSourceLabel,
    Function({Object? e, StackTrace? st})? onFailure,
    VoidCallback? onSuccess,
  }) async {
    // 0. Guard: never attempt a call with an empty/blank number. Otherwise we
    // POST a malformed URL (".../phone_call/") and fall back to a blank
    // `tel://` dialer, which reads as a false success. Show a graceful error
    // instead.
    if (phoneNumber.trim().isEmpty) {
      MonitoringServiceHelper.logError("CALL_ABORTED_EMPTY_PHONE", {
        "callSourceLabel": callSourceLabel,
      });
      final emptyCtx = context ?? GlobalState().navigatorKey.currentContext;
      if (emptyCtx != null && emptyCtx.mounted) {
        final languageProvider = emptyCtx.read<LanguageProvider>();
        _showCustomSnackBar(
          emptyCtx,
          message: languageProvider.getMessage('call_number_unavailable',
              'Support number unavailable. Please try again later.'),
          backgroundColor: AppColors.r50,
        );
      }
      return;
    }

    try {
      // 1. Trigger the API call
      final response =
          await CallingService.initiateCall(phoneNumber: phoneNumber);

      final context2 = context ?? GlobalState().navigatorKey.currentContext;

      // 2. Safety check: Ensure the widget is still in the tree before showing UI
      if (context2 == null || !context2.mounted) return;

      final languageProvider = context2.read<LanguageProvider>();

      // 3. Logic for Success (200) vs Failure
      if (response != null && response.statusCode == 200) {
        _showCustomSnackBar(
          context2,
          message: languageProvider.getMessage('call_initiation_successful',
              "Call has been initiated successfully"),
          backgroundColor: AppColors.g40,
        );
      } else {
        _launchDialerAsFallback(
          phoneNumber: phoneNumber,
          callSourceLabel: callSourceLabel,
          onFailure: onFailure,
          onSuccess: onSuccess,
        );
      }
    } catch (e) {
      _launchDialerAsFallback(
        phoneNumber: phoneNumber,
        callSourceLabel: callSourceLabel,
        onFailure: onFailure,
        onSuccess: onSuccess,
      );
      MonitoringServiceHelper.logError(
          "FAILED_TO_INITIATE_CALL_FROM_CALLING_SERVICE", {
        "error": e.toString(),
      });
    }
  }

  static void _launchDialerAsFallback(
      {required String phoneNumber,
      String? callSourceLabel,
      Function({Object? e, StackTrace? st})? onFailure,
      VoidCallback? onSuccess}) async {
    try {
      final Uri phoneUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );
      if (await canLaunchUrl(phoneUri)) {
        launchUrl(
          phoneUri,
          mode: LaunchMode.externalApplication,
        );
        onSuccess?.call();
      } else {
        MonitoringServiceHelper.logError("UNABLE_TO_LAUNCH_PHONE_URI", {
          "callSourceLabel": callSourceLabel,
        });
        if (onFailure != null) {
          onFailure();
        }
      }
    } catch (e, st) {
      MonitoringServiceHelper.logError("FAILED_TO_LAUNCH_PHONE_DIALER", {
        "error": e.toString(),
        "callSourceLabel": callSourceLabel,
        "stack_trace": st.toString(),
      });
      if (onFailure != null) {
        onFailure(e: e, st: st);
      }
    }
  }

  // Helper method to keep the code DRY (Don't Repeat Yourself)
  static void _showCustomSnackBar(BuildContext context,
      {required String message, required Color backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: AppColors.n0),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating, // Makes it look modern
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

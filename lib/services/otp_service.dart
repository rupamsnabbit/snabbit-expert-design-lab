import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/server_requests/login_http.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:dio/dio.dart';
import 'package:otpless_headless_flutter/otpless_flutter.dart' show Otpless;
import 'package:otpless_headless_flutter/otpless_flutter_method_channel.dart'
    show OtplessResultCallback;
import 'package:sms_autofill/sms_autofill.dart';

class OtpServiceResult {
  final bool success;
  final String? token;
  final String? error;
  final String? deliveryChannel;
  final String? phoneNumber;
  final String? authMethod;

  OtpServiceResult({
    required this.success,
    this.token,
    this.error,
    this.deliveryChannel,
    this.phoneNumber,
    this.authMethod,
  });
}

enum OtplessConfig {
  sms,
  whatsapp,
  call,
  trueCaller;

  static OtplessConfig? fromString(String? name) {
    switch (name?.toLowerCase()) {
      case "sms":
        return OtplessConfig.sms;
      case "whatsapp":
        return OtplessConfig.whatsapp;
      case "call":
        return OtplessConfig.call;
      case "truecaller":
        return OtplessConfig.trueCaller;
      default:
        return null;
    }
  }

  String get otplessName {
    switch (this) {
      case OtplessConfig.sms:
        return "SMS";
      case OtplessConfig.whatsapp:
        return "WHATSAPP";
      case OtplessConfig.call:
        return "VOICE_CALL";
      case OtplessConfig.trueCaller:
        return "TRUE_CALLER";
    }
  }
}

/// Debug-only OTPless traces; no-op in release/profile.
void otplessDebugLog(String message) {
  if (kDebugMode) {
    debugPrint('[Otpless] $message');
  }
}

class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  Otpless? _otplessInstance;

  /// [initialize] stores this so [InputOtp] can restore after [setOtplessResponseCallback].
  OtplessResultCallback? _defaultOtplessCallback;

  /// OTP read while [SendOtp] still owns the SDK callback (race before [InputOtp] rebinds).
  String? _pendingOtplessAutoReadOtp;

  get otplessInstance => _otplessInstance;

  OtpServiceProvider get currentProvider {
    if (kDebugMode && GlobalState().debugForceEdumarcOtpProvider) {
      return OtpServiceProvider.edumarc;
    }
    return GlobalState().appConfig?.otpServiceProvider ??
        OtpServiceProvider.edumarc;
  }

  set currentProvider(OtpServiceProvider provider) {
    GlobalState().appConfig?.otpServiceProvider = provider;
  }

  Future<void> initialize({
    String? otplessAppId,
    OtplessResultCallback? onOtplessResponse,
  }) async {
    if (currentProvider != OtpServiceProvider.otpless) {
      otplessDebugLog(
          'initialize skipped: provider=${currentProvider.name} (not otpless)');
      return;
    }
    if (otplessAppId == null || onOtplessResponse == null) {
      final missing = <String>[
        if (otplessAppId == null) 'appId',
        if (onOtplessResponse == null) 'callback',
      ].join(', ');
      otplessDebugLog('initialize skipped: missing $missing');
      return;
    }
    await _initializeOtpless(otplessAppId, onOtplessResponse);
  }

  Future<void> _initializeOtpless(
      String appId, OtplessResultCallback onOtplessResponse) async {
    try {
      otplessDebugLog(
          'SDK initialize starting (appId suffix: …${appId.length > 4 ? appId.substring(appId.length - 4) : appId})');
      _otplessInstance = Otpless();
      await _otplessInstance?.initialize(appId);
      _defaultOtplessCallback = onOtplessResponse;
      await _otplessInstance?.setResponseCallback(onOtplessResponse);
      otplessDebugLog('SDK initialize done, callback registered');
    } catch (e, st) {
      otplessDebugLog('SDK initialize failed: $e\n$st');
      _otplessInstance = null;
      rethrow;
    }
  }

  Future<OtpServiceResult> sendOtp({
    required String phoneNumber,
    required String countryCode,
    String? appSignature,
    OtplessResultCallback? onOtplessResponse,
    String? deliveryChannel,
    String? authType,
  }) async {
    final sdkReady = await _otplessInstance?.isSdkReady() == true;
    otplessDebugLog(
        'sendOtp: sdkReady=$sdkReady provider=${currentProvider.name} hasCallback=${onOtplessResponse != null}');
    if (sdkReady &&
        currentProvider == OtpServiceProvider.otpless &&
        onOtplessResponse != null) {
      return await _sendOtpViaOtpless(
        phoneNumber,
        countryCode,
        onOtplessResponse,
        deliveryChannel: deliveryChannel,
        authType: authType,
      );
    } else {
      otplessDebugLog('sendOtp: using traditional (edumarc) HTTP path');
      return await _sendOtpViaTraditional(
        phoneNumber,
        countryCode,
        appSignature,
      );
    }
  }

  Future<OtpServiceResult> _sendOtpViaOtpless(
    String phoneNumber,
    String countryCode,
    OtplessResultCallback onOtplessResponse, {
    String? deliveryChannel,
    String? authType,
  }) async {
    try {
      if (_otplessInstance == null) {
        otplessDebugLog('start() aborted: instance null');
        return OtpServiceResult(
          success: false,
          error: "OTPless not initialized",
        );
      }

      final Map<String, dynamic> args = {
        "phone": phoneNumber,
        "countryCode": countryCode,
        if (deliveryChannel != null && deliveryChannel.isNotEmpty)
          "deliveryChannel": deliveryChannel,
        if (authType != null && authType.isNotEmpty) "authType": authType,
      };
      otplessDebugLog(
          'start() deliveryChannel=${deliveryChannel ?? "(default)"} authType=${authType ?? "(default)"} countryCode=$countryCode phoneLen=${phoneNumber.length}');
      _otplessInstance?.start(onOtplessResponse, args);
      return OtpServiceResult(
        success: true,
        deliveryChannel: "OTPless",
      );
    } catch (e) {
      otplessDebugLog('start() failed: $e');
      return OtpServiceResult(
        success: false,
        error: "Failed to send OTP via OTPless: $e",
      );
    }
  }

  Future<OtpServiceResult> _sendOtpViaTraditional(
      String phoneNumber, String countryCode, String? appSignature) async {
    try {
      Response? response = await LoginHttp.sendOtp(data: {
        "country_code": countryCode,
        "phone": phoneNumber,
        "app_signature": appSignature ?? await SmsAutoFill().getAppSignature,
      });

      if (response != null) {
        return OtpServiceResult(
          success: true,
          deliveryChannel: "SMS",
        );
      } else {
        return OtpServiceResult(
          success: false,
          error: "Failed to send OTP",
        );
      }
    } catch (e) {
      return OtpServiceResult(
        success: false,
        error: "Error sending OTP: $e",
      );
    }
  }

  Future<void> setOtplessResponseCallback(
      OtplessResultCallback callback) async {
    if (_otplessInstance == null) return;
    await _otplessInstance!.setResponseCallback(callback);
  }

  Future<void> restoreDefaultOtplessResponseCallback() async {
    if (_otplessInstance == null || _defaultOtplessCallback == null) return;
    await _otplessInstance!.setResponseCallback(_defaultOtplessCallback!);
  }

  void setPendingOtplessAutoReadOtp(String otp) {
    _pendingOtplessAutoReadOtp = otp;
  }

  String? takePendingOtplessAutoReadOtp() {
    final v = _pendingOtplessAutoReadOtp;
    _pendingOtplessAutoReadOtp = null;
    return v;
  }

  Future<void> startListeningForSms() async {
    if (currentProvider == OtpServiceProvider.edumarc) {
      await SmsAutoFill().listenForCode();
    }
  }

  Future<void> stopListeningForSms() async {
    if (currentProvider == OtpServiceProvider.edumarc) {
      await SmsAutoFill().unregisterListener();
    }
  }

  Future<String> getAppSignature() async {
    if (currentProvider == OtpServiceProvider.edumarc) {
      return await SmsAutoFill().getAppSignature;
    }
    return "";
  }

  void dispose() {
    if (currentProvider == OtpServiceProvider.edumarc) {
      SmsAutoFill().unregisterListener();
    }
    if (_otplessInstance != null) {
      otplessDebugLog('dispose: clearing Otpless instance');
    }
    _otplessInstance = null;
  }
}

// ignore_for_file: use_build_context_synchronously
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:snabbit_runner/services/analytics/onboarding_analytics.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/network_channel.dart';
import 'package:snabbit_runner/services/otp_service.dart';
import 'package:snabbit_runner/services/security/secure_storage_service.dart';
import 'package:snabbit_runner/services/server_requests/login_http.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/doc_text.dart';
import 'package:snabbit_runner/widgets/pdf_view.dart';
import 'package:snabbit_runner/pages/login/input_otp.dart';
import 'package:snabbit_runner/pages/login/select_language_v2.dart';
import 'package:snabbit_runner/config/frontend_preview.dart';
import 'package:snabbit_runner/utils/colors.dart';
import '../../utils/app_strings.dart';
import '../../utils/custom_themes/text_themes.dart';
import '../../widgets/location_permission_confirmation.dart';

class SendOtp extends StatefulWidget {
  static const String routeName = "/send_otp";

  const SendOtp({super.key});

  @override
  State<SendOtp> createState() => _SendOtpState();
}

class _SendOtpState extends State<SendOtp> {
  TextEditingController phoneNumberTextController = TextEditingController();

  bool loading = false;
  String? _responseMessage = "";
  bool _fallbackTriggered = false;
  bool _otplessOtpDispatched = false;
  bool _otpScreenPushed = false;

  @override
  void initState() {
    super.initState();
    _initializeOtpService();
    OnboardingAnalytics.logEvent(TrackingEvents.phoneNumberScreenLoad, {});
  }

  void _initializeOtpService() async {
    if (FrontendPreview.enabled) return;

    try {
      await OtpService().initialize(
        // Runner app OTPless App ID (prod). Deeplink scheme in AndroidManifest.xml must match (lowercase).
        otplessAppId: "KLZNUPDU4MTAQ4UH7ESP",
        onOtplessResponse: onOtplessResponse,
      );
    } catch (e) {
      otplessDebugLog('OTPless SDK init failed, falling back to Edumarc: $e');
      OtpService().currentProvider = OtpServiceProvider.edumarc;
      ClevertapSetup.logEvent(TrackingEvents.otplessFailed, {
        "callback": "SDK_INIT_FAILED",
        "error": e.toString(),
      });
    }
  }

  // OTPless error codes that indicate unrecoverable failure — auto-fallback to Edumarc.
  static const _fatalOtplessErrorCodes = {7121, 401, 7025, 9106, 5900};

  bool _shouldAutoFallback(dynamic statusCode) {
    final code = statusCode is int ? statusCode : int.tryParse('$statusCode');
    return code != null && _fatalOtplessErrorCodes.contains(code);
  }

  // Silently switch to Edumarc and auto-send OTP if user was waiting.
  void _autoFallbackToEdumarc(
      {String? trackingEvent, String? trackingCallback}) {
    if (_fallbackTriggered || _otplessOtpDispatched) return;
    _fallbackTriggered = true;
    OtpService().currentProvider = OtpServiceProvider.edumarc;
    if (trackingEvent != null) {
      ClevertapSetup.logEvent(trackingEvent, {
        "phone": phoneNumberTextController.text,
        if (trackingCallback != null) "callback": trackingCallback,
      });
    }
    if (mounted && loading && phoneNumberTextController.text.length == 10) {
      _sendOtpViaEdumarc(phoneNumberTextController.text).catchError((e) {
        otplessDebugLog('auto-fallback Edumarc sendOtp failed: $e');
        if (mounted) setState(() => loading = false);
      });
    } else if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  void onOtplessResponse(dynamic result) {
    try {
      if (result is! Map) {
        otplessDebugLog(
            'callback SendOtp ignored: non-Map (${result.runtimeType})');
        _autoFallbackToEdumarc(
          trackingEvent: TrackingEvents.otplessFailed,
          trackingCallback: "NON_MAP_RESULT",
        );
        return;
      }
      debugPrint('onOtplessResponse result: ${result.toString()}');

      final nested = result['response'];
      final authType = nested is Map ? nested['authType'] : null;
      otplessDebugLog(
          'callback SendOtp responseType=${result['responseType']} statusCode=${result['statusCode']} authType=$authType');

      OtpService().otplessInstance?.commitResponse(result);

      final responseType = result['responseType'];

      switch (responseType) {
        case "SDK_READY":
          otplessDebugLog(
              'callback SendOtp SDK_READY result=${result["response"]}');
          break;

        case "FAILED":
          if (loading) {
            _autoFallbackToEdumarc(
              trackingEvent: TrackingEvents.otplessFailed,
              trackingCallback: "FAILED",
            );
          } else {
            otplessDebugLog(
                'FAILED (passive, before user action) — OTPless still available');
          }
          break;

        case "INITIATE":
          if (result["statusCode"] == 200) {
            final authTypeVal = result["response"]?["authType"];
            if (authTypeVal == "OTP") {
              _otplessOtpDispatched = true;
              if (mounted && !_otpScreenPushed) {
                _otpScreenPushed = true;
                setState(() {
                  loading = false;
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InputOtp(
                      phoneNumber: phoneNumberTextController.text,
                      isOtpless: true,
                    ),
                  ),
                ).then((_) => _otpScreenPushed = false);
              }
            } else if (authTypeVal == "SILENT_AUTH") {
              if (mounted) {
                setState(() {
                  loading = true;
                });
              }
            } else if (authTypeVal == "TRUE_CALLER") {
              otplessDebugLog('INITIATE TRUE_CALLER — no action taken');
            } else {
              otplessDebugLog(
                  'INITIATE unknown authType=$authTypeVal, falling back');
              _autoFallbackToEdumarc(
                trackingEvent: TrackingEvents.otplessFailed,
                trackingCallback: "INITIATE_UNKNOWN_AUTH_TYPE",
              );
            }
          } else if (_shouldAutoFallback(result["statusCode"])) {
            _autoFallbackToEdumarc(
              trackingEvent: TrackingEvents.otplessFailed,
              trackingCallback: "INITIATE_${result["statusCode"]}",
            );
          } else {
            MonitoringServiceHelper.logError(
              "otpless_initiate_unknown_failure",
              {
                "phone": phoneNumberTextController.text,
                "status_code": result["statusCode"],
                "auth_type": result["response"]?["authType"],
              },
            );
            if (mounted) {
              setState(() {
                loading = false;
              });
            }
          }
          break;

        case "OTP_AUTO_READ":
          // SDK callback may still be SendOtp's until InputOtp rebinds; buffer for handoff race.
          final otp = result["response"]?["otp"];
          final otpStr = otp?.toString();
          if (otpStr != null && otpStr.isNotEmpty) {
            OtpService().setPendingOtplessAutoReadOtp(otpStr);
          }
          otplessDebugLog(
              'SendOtp OTP_AUTO_READ buffered=${otpStr != null && otpStr.isNotEmpty}');
          break;

        case "VERIFY":
          final verifyAuthType = result["response"]?["authType"];
          otplessDebugLog(
              'callback SendOtp VERIFY authType=$verifyAuthType statusCode=${result["statusCode"]}');

          if (verifyAuthType == "SILENT_AUTH" && result["statusCode"] == 9106) {
            // Per OTPless docs, 9106 = SNA and all SmartAuth fallbacks exhausted.
            // Only safe time to send our own Edumarc OTP without overlapping OTPless.
            _autoFallbackToEdumarc(
              trackingEvent: TrackingEvents.snaFailed,
              trackingCallback: "VERIFY_9106",
            );
          } else if (verifyAuthType == "SILENT_AUTH") {
            // Non-9106 SNA verify failure: per docs, OTPless will follow up
            // with INITIATE for the next configured channel. We don't fall
            // back here, but we DO emit a snaFailed event so the funnel can
            // tell "SNA failed, OTPless retried" apart from "SNA failed
            // terminally, we fell back to Edumarc".
            ClevertapSetup.logEvent(TrackingEvents.snaFailed, {
              "phone": phoneNumberTextController.text,
              "callback": "VERIFY_NON_9106",
              "status_code": result["statusCode"],
              "delivery_channel": result["response"]?["deliveryChannel"],
            });
            MonitoringServiceHelper.logError(
              "otpless_verify_non_9106",
              {
                "phone": phoneNumberTextController.text,
                "status_code": result["statusCode"],
                "delivery_channel": result["response"]?["deliveryChannel"],
              },
            );
          }
          // Any other authType (TRUE_CALLER, etc.): OTPless will follow up
          // with INITIATE for the next configured channel and deliver its
          // own OTP. Do not fall back here or the user receives two SMSes
          // from two providers.
          break;

        case "DELIVERY_STATUS":
          _otplessOtpDispatched = true;
          break;

        case "ONETAP":
          verifyUser(otplessResult: Map<String, dynamic>.from(result));
          break;

        case "FALLBACK_TRIGGERED":
          // OTPless switching channels internally (e.g. WhatsApp→SMS). Not a failure — do not switch to Edumarc.
          otplessDebugLog(
              'SendOtp FALLBACK_TRIGGERED newChannel=${result["response"]?["deliveryChannel"]}');
          break;

        default:
          otplessDebugLog('SendOtp unhandled responseType=$responseType');
          if (mounted && loading) {
            setState(() => loading = false);
          }
          break;
      }
    } catch (e, st) {
      otplessDebugLog('callback SendOtp error: $e\n$st');
      _autoFallbackToEdumarc(
        trackingEvent: TrackingEvents.otplessFailed,
        trackingCallback: "CALLBACK_EXCEPTION",
      );
    }
  }

  Future<void> verifyUser({Map<String, dynamic>? otplessResult}) async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }
    try {
      // Build a new map — don't mutate the SDK's callback result
      final Map<String, dynamic> requestData = {
        if (otplessResult != null) ...otplessResult,
        "country_code": "+91",
        "phone": phoneNumberTextController.text,
      };
      otplessDebugLog(
          'verifyToken request (SendOtp) otplessKeys=${otplessResult?.keys.join(",") ?? "(none)"}');
      final response = await LoginHttp.verifyToken(data: requestData);
      otplessDebugLog(
          'verifyToken response (SendOtp) status=${response?.statusCode}');
      if (response?.statusCode == 200) {
        final data = response?.data;
        final accessToken = data?[AppStrings.accessToken];
        if (accessToken != null) {
          await SecureStorageUtils.saveAccessToken(accessToken);
          await NetworkChannel.pushTokenAfterLogin(accessToken);
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, SelectLanguageV2.routeName, (route) => false);
          }
        } else {
          if (mounted) {
            setState(() {
              _responseMessage = "Invalid response from server.";
              loading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _responseMessage = "Verification failed. Please try again.";
            loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _responseMessage = "Something went wrong";
          loading = false;
        });
      }
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    if (OtpService().currentProvider == OtpServiceProvider.otpless) {
      await _sendOtpViaOtpless(phoneNumber);
    } else {
      await _sendOtpViaEdumarc(phoneNumber);
    }
  }

  Future<void> _sendOtpViaOtpless(String phoneNumber) async {
    otplessDebugLog(
        '_sendOtpViaOtpless invoked phoneLen=${phoneNumber.length}');
    final result = await OtpService().sendOtp(
      phoneNumber: phoneNumber,
      countryCode: "+91",
      onOtplessResponse: onOtplessResponse,
    );
    if (!result.success && mounted) {
      setState(() {
        loading = false;
        _responseMessage = result.error ?? "Failed to send OTP";
      });
    }
    // Success is handled via onOtplessResponse callback
  }

  Future<void> _sendOtpViaEdumarc(String phoneNumber) async {
    try {
      String appSignature = await SmsAutoFill().getAppSignature;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone_number', phoneNumber);
      final response = await LoginHttp.sendOtp(
        data: {
          "phone": phoneNumber,
          "app_signature": appSignature,
        },
      );

      if (!mounted) return;
      if (response?.statusCode == 200) {
        setState(() {
          loading = false;
        });
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => InputOtp(phoneNumber: phoneNumber)));
      } else {
        try {
          _responseMessage = response?.data['errors'][0]['message'] ?? "";
        } catch (_) {
          if (GlobalState().appError.value == AppErrorType.invalidRequest) {
            _responseMessage =
                "${GlobalState().appError.value.description ?? ""} - ${response?.statusCode ?? ""}";
          } else {
            throw "";
          }
        }
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _responseMessage =
            GlobalState().appError.value.description ?? "Something went wrong";
      });
    }
  }

  @override
  void dispose() {
    phoneNumberTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: RichText(
          text: TextSpan(
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontSize: 16),
            children: const <TextSpan>[
              TextSpan(
                text: 'Welcome to ',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                ),
              ),
              TextSpan(
                text: 'Snabbit',
                style: TextStyle(fontSize: 24, color: AppColors.brand),
              ),
            ],
          ),
        ),
      ),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: canContinue() && !loading
                ? () async {
                    final phone = phoneNumberTextController.text;

                    if (FrontendPreview.enabled) {
                      if (mounted) {
                        setState(() {
                          loading = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InputOtp(phoneNumber: phone),
                          ),
                        );
                      }
                      return;
                    }

                    OnboardingAnalytics.logEvent(
                        TrackingEvents.phoneNumberScreenCtaClick, {
                      'cta_text': 'continue',
                      'phone_length': phone.length,
                      'otp_provider': OtpService().currentProvider.name,
                    });
                    setState(() {
                      loading = true;
                    });
                    try {
                      await sendOtp(phoneNumberTextController.text);
                      final prefs = await SharedPreferences.getInstance();
                      bool? cleverTapAccountExists =
                          prefs.getBool(AppStrings.cleverTapAccountExists);
                      if (cleverTapAccountExists != true) {
                        await ClevertapSetup.logEvent(
                            TrackingEvents.loginOtpSent, {
                          'action': "send otp button clicked",
                        });
                      }
                      if (OtpService().currentProvider ==
                          OtpServiceProvider.edumarc) {
                        if (mounted) {
                          setState(() {
                            loading = false;
                          });
                        }
                      }
                    } catch (e) {
                      otplessDebugLog('Continue button error: $e');
                      if (mounted) {
                        setState(() {
                          loading = false;
                        });
                      }
                    }
                  }
                : null,
            child: loading
                ? CupertinoActivityIndicator()
                : Text(
                    "Continue",
                  ),
          ),
        ),
      ],
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login or Sign up to continue',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: phoneNumberTextController,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      ],
                      maxLines: 1,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                          suffixIcon: phoneNumberTextController.text.isNotEmpty
                              ? InkWell(
                                  onTap: () {
                                    setState(() {
                                      phoneNumberTextController.text = "";
                                    });
                                  },
                                  child: Transform.scale(
                                    scale: 0.4,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xffEAEAF1),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: AppColors.b40,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                          hintText: "Enter mobile number",
                          hintStyle: AppTextTheme.hintStyle,
                          counter: const SizedBox()),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "We will send an OTP to confirm the number",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.n70,
                          ),
                    ),
                    if (_responseMessage != null &&
                        _responseMessage!.isNotEmpty)
                      Text(
                        "$_responseMessage",
                        style: AppTextTheme.errStyle,
                      ),
                  ],
                ),
              ),
              RichDocText.fromJson(
                GlobalState().appConfig?.docText ??
                    {
                      "text": "By clicking continue, I accept the {{doc2}}",
                      "data": [
                        {
                          "key": "doc2",
                          "text": "Privacy Policy",
                          "url":
                              "https://snabbit-app-policies.s3.ap-south-1.amazonaws.com/Privacy_Policy_Expert_App.pdf",
                        }
                      ]
                    },
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.n80,
                    ),
                onLinkTap: (key) {
                  OnboardingAnalytics.logEvent(
                      TrackingEvents.tncLinkClicked, {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool canContinue() {
    if (phoneNumberTextController.text.length == 10) {
      return true;
    } else {
      return false;
    }
  }
}

import 'dart:async' show Future, StreamSubscription, Timer, unawaited;
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:snabbit_runner/pages/login/select_language_v2.dart';
import 'package:snabbit_runner/pages/frontend_preview/frontend_preview_home.dart';
import 'package:snabbit_runner/config/frontend_preview.dart';
import 'package:snabbit_runner/services/analytics/onboarding_analytics.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/network_channel.dart';
import 'package:snabbit_runner/services/otp_service.dart';
import 'package:snabbit_runner/services/security/secure_storage_service.dart';
import 'package:snabbit_runner/services/server_requests/login_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/gap.dart';
import '../../utils/common_methods.dart';

class InputOtp extends StatefulWidget {
  const InputOtp({
    super.key,
    required this.phoneNumber,
    this.isOtpless = false,
  });

  final String phoneNumber;
  final bool isOtpless;

  @override
  State<InputOtp> createState() => _InputOtpState();
}

class _InputOtpState extends State<InputOtp> {
  TextEditingController otpTextController = TextEditingController();
  int counter = 30;
  Timer? timer;
  bool isError = false;
  bool loadingResendOtp = false;
  bool loadingVerify = false;
  String? _responseMessage;
  bool otpResent = false;
  String codeValue = "";
  bool _otpFilledByAutoRead = false;
  int _otpAttemptCount = 0;
  StreamSubscription<String>? _smsSubscription;

  @override
  void initState() {
    super.initState();
    if (FrontendPreview.enabled) {
      // Keep the OTP surface visible for design review, but do not register
      // SMS listeners or initialize an authentication provider.
    } else if (!widget.isOtpless) {
      initPlatformState();
    } else {
      unawaited(_bindOtplessCallbackForInputScreen());
    }

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        counter -= 1;
      });
      if (counter <= 0) {
        t.cancel();
      }
    });

    OnboardingAnalytics.resetResendCount();
    unawaited(_fireOtpScreenLoad());
  }

  void initPlatformState() async {
    // Single SMS listener for Edumarc path. PinFieldAutoFill was removed to avoid
    // double-registering the Android SmsRetriever, which caused the code stream
    // to emit twice and verifyOtp() to fire twice in parallel.
    await SmsAutoFill().listenForCode();
    _smsSubscription = SmsAutoFill().code.listen((code) {
      if (!mounted || code.isEmpty) return;
      setState(() {
        otpTextController.text = code;
        codeValue = code;
      });
      if (code.length == 4) {
        unawaited(verifyOtp());
      }
    });
  }

  Future<void> _fireOtpScreenLoad() async {
    if (FrontendPreview.enabled) return;

    bool smsGranted = false;
    try {
      smsGranted = (await Permission.sms.status).isGranted;
    } catch (_) {}
    OnboardingAnalytics.logEvent(TrackingEvents.otpScreenLoad, {
      'source': 'phone_number_screen',
      'sms_permission_granted': smsGranted ? 1 : 0,
      ..._otpEventBaseProps(),
    });
  }

  /// Common OTP-flow props attached to every OTP event in this screen.
  /// Read at fire time so otp_provider reflects any mid-flow fallback.
  Map<String, dynamic> _otpEventBaseProps() => {
        'phone_masked': OnboardingAnalytics.maskPhone(widget.phoneNumber),
        'otp_provider': OtpService().currentProvider.name,
        'resend_count': OnboardingAnalytics.resendCount,
      };

  /// OTPless SDK keeps one Dart callback ([MethodChannelOtplessFlutter._callback]).
  /// After [OtpService.sendOtp] → [Otpless.start], events still go to [SendOtp] unless we rebind here.
  Future<void> _bindOtplessCallbackForInputScreen() async {
    await OtpService().setOtplessResponseCallback(onOtplessResponse);
    final pending = OtpService().takePendingOtplessAutoReadOtp();
    if (!mounted) return;
    if (pending != null && pending.isNotEmpty) {
      setState(() {
        otpTextController.text = pending;
        codeValue = pending;
      });
    }
  }

  void onOtplessResponse(dynamic result) {
    try {
      if (result is! Map) {
        otplessDebugLog(
            'callback InputOtp ignored: non-Map (${result.runtimeType})');
        if (mounted) {
          setState(() {
            loadingVerify = false;
          });
        }
        return;
      }

      final nested = result['response'];
      final authType = nested is Map ? nested['authType'] : null;
      otplessDebugLog(
          'callback InputOtp responseType=${result['responseType']} statusCode=${result['statusCode']} authType=$authType');

      OtpService().otplessInstance?.commitResponse(result);

      final responseType = result['responseType'];

      switch (responseType) {
        case "ONETAP":
          _verifyOtplessToken(Map<String, dynamic>.from(result));
          break;

        case "OTP_AUTO_READ":
          final otp = result["response"]?["otp"]?.toString();
          if (otp != null && otp.isNotEmpty && mounted) {
            setState(() {
              otpTextController.text = otp;
              codeValue = otp;
              _otpFilledByAutoRead = true;
            });
          }
          break;

        case "INITIATE":
          // OTP re-sent or channel fallback
          if (mounted) {
            setState(() {
              loadingVerify = false;
            });
          }
          break;

        case "VERIFY":
          if (result["statusCode"] != 200) {
            _otpAttemptCount += 1;
            OnboardingAnalytics.logEvent(TrackingEvents.otpVerificationFailed, {
              ..._otpEventBaseProps(),
              'error_type': 'otpless_${result["statusCode"] ?? "unknown"}',
              'attempt_count': _otpAttemptCount,
              'error_copy': 'Incorrect OTP entered. Please enter again',
            });
            if (mounted) {
              setState(() {
                isError = true;
                loadingVerify = false;
              });
            }
          }
          break;

        case "FAILED":
          // OTPless itself failed — switch to Edumarc and go back so user can retry via traditional OTP.
          OtpService().currentProvider = OtpServiceProvider.edumarc;
          ClevertapSetup.logEvent(TrackingEvents.otplessFailed, {
            "phone": widget.phoneNumber,
            "callback": "FAILED_ON_INPUT",
          });
          if (mounted) {
            Navigator.of(context).pop();
          }
          break;

        default:
          break;
      }
    } catch (e, st) {
      otplessDebugLog('callback InputOtp error: $e\n$st');
      OtpService().currentProvider = OtpServiceProvider.edumarc;
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _verifyOtplessToken(Map<String, dynamic> otplessResult) async {
    if (mounted) {
      setState(() {
        loadingVerify = true;
      });
    }
    try {
      // Build a new map — don't mutate the SDK's callback result
      final Map<String, dynamic> requestData = {
        ...otplessResult,
        "country_code": "+91",
        "phone": widget.phoneNumber,
      };
      otplessDebugLog(
          'verifyToken request (InputOtp) otplessKeys=${otplessResult.keys.join(",")}');
      final response = await LoginHttp.verifyToken(data: requestData);
      otplessDebugLog(
          'verifyToken response (InputOtp) status=${response?.statusCode}');
      if (response?.statusCode == 200) {
        final data = response?.data;
        final accessToken = data?[AppStrings.accessToken];
        if (accessToken != null) {
          SecureStorageUtils.saveAccessToken(accessToken);
          await NetworkChannel.pushTokenAfterLogin(accessToken);
          await SecureStorageUtils.saveAccessToken(accessToken);
          OnboardingAnalytics.logEvent(TrackingEvents.otpVerificationSuccess, {
            ..._otpEventBaseProps(),
            'otp_entry_method': _otpFilledByAutoRead ? 'auto_read' : 'manual',
          });
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, SelectLanguageV2.routeName, (route) => false);
          }
        } else {
          _otpAttemptCount += 1;
          OnboardingAnalytics.logEvent(TrackingEvents.otpVerificationFailed, {
            ..._otpEventBaseProps(),
            'error_type': 'http_200_no_token',
            'attempt_count': _otpAttemptCount,
            'error_copy': 'Incorrect OTP entered. Please enter again',
          });
          if (mounted) {
            setState(() {
              isError = true;
              loadingVerify = false;
            });
          }
        }
      } else {
        _otpAttemptCount += 1;
        OnboardingAnalytics.logEvent(TrackingEvents.otpVerificationFailed, {
          ..._otpEventBaseProps(),
          'error_type': 'http_${response?.statusCode ?? 'unknown'}',
          'attempt_count': _otpAttemptCount,
          'error_copy': 'Incorrect OTP entered. Please enter again',
        });
        if (mounted) {
          setState(() {
            isError = true;
            loadingVerify = false;
          });
        }
      }
    } catch (e) {
      _otpAttemptCount += 1;
      OnboardingAnalytics.logEvent(TrackingEvents.otpVerificationFailed, {
        ..._otpEventBaseProps(),
        'error_type': 'network_error',
        'attempt_count': _otpAttemptCount,
        'error_copy': 'Incorrect OTP entered. Please enter again',
      });
      if (mounted) {
        setState(() {
          isError = true;
          loadingVerify = false;
        });
      }
    }
  }

  Future<void> sendOtp() async {
    if (widget.isOtpless) {
      final result = await OtpService().sendOtp(
        phoneNumber: widget.phoneNumber,
        countryCode: "+91",
        onOtplessResponse: onOtplessResponse,
      );
      if (mounted) {
        setState(() {
          loadingResendOtp = false;
          otpResent = result.success;
        });
      }
    } else {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone_number', widget.phoneNumber);
        String appSignature = await SmsAutoFill().getAppSignature;
        final response = await LoginHttp.sendOtp(
          data: {
            "phone": widget.phoneNumber,
            "app_signature": appSignature,
          },
        );
        if (!mounted) return;
        if (response?.statusCode == 200) {
          setState(() {
            otpResent = true;
            loadingResendOtp = false;
          });
        } else {
          setState(() {
            otpResent = false;
            loadingResendOtp = false;
            _responseMessage = 'Failed to send OTP: ${response?.data}';
          });
          showSnackbar(context, _responseMessage.toString());
        }
      } catch (e) {
        otplessDebugLog('sendOtp Edumarc resend error: $e');
        if (mounted) {
          setState(() {
            loadingResendOtp = false;
          });
          showSnackbar(context, "Failed to resend OTP. Please try again.");
        }
      }
    }
  }

  Future<void> _resendViaChannel(String deliveryChannel) async {
    setState(() {
      loadingResendOtp = true;
      isError = false;
    });
    try {
      ClevertapSetup.logEvent(TrackingEvents.otplessChannelSwitch, {
        "phone": widget.phoneNumber,
        "channel": deliveryChannel,
      });
      OnboardingAnalytics.incrementResendCount();
      OnboardingAnalytics.logEvent(TrackingEvents.otpResendCtaClick, {
        ..._otpEventBaseProps(),
      });
      final result = await OtpService().sendOtp(
        phoneNumber: widget.phoneNumber,
        countryCode: "+91",
        onOtplessResponse: onOtplessResponse,
        deliveryChannel: deliveryChannel,
        authType: "OTP",
      );
      if (mounted) {
        setState(() {
          loadingResendOtp = false;
        });
        if (result.success) {
          _resetTimer();
        } else {
          showSnackbar(context, "Failed to resend OTP. Please try again.");
        }
      }
    } catch (e) {
      otplessDebugLog('_resendViaChannel error: $e');
      if (mounted) {
        setState(() {
          loadingResendOtp = false;
        });
        showSnackbar(context, "Failed to resend OTP. Please try again.");
      }
    }
  }

  void _resetTimer() {
    timer?.cancel();
    if (!mounted) return;
    setState(() {
      counter = 30;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        counter -= 1;
      });
      if (counter == 0) {
        t.cancel();
      }
    });
  }

  List<Widget> _buildChannelButtons() {
    final channels = GlobalState().appConfig?.otplessApplicableChannels ?? [];
    return channels.map((config) {
      final String label;
      final IconData icon;
      switch (config) {
        case OtplessConfig.sms:
          label = "SMS";
          icon = Icons.sms_outlined;
        case OtplessConfig.whatsapp:
          label = "WhatsApp";
          icon = Icons.chat_outlined;
        case OtplessConfig.call:
          label = "Call";
          icon = Icons.phone_outlined;
        case OtplessConfig.trueCaller:
          return const SizedBox.shrink();
      }
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: SizedBox(
          height: 32.h,
          child: OutlinedButton.icon(
            onPressed: loadingResendOtp
                ? null
                : () => _resendViaChannel(config.otplessName),
            icon: Icon(icon, size: 14.r),
            label: Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.n90,
                    )),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.n90,
              padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
              side: BorderSide(color: AppColors.n40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(80.r),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> verifyOtp() async {
    if (loadingVerify) return;
    if (otpTextController.text.length != 4) return;
    setState(() {
      loadingVerify = true;
      isError = false;
    });

    if (FrontendPreview.enabled) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          FrontendPreviewHome.routeName,
          (route) => false,
        );
      }
      return;
    }

    if (widget.isOtpless) {
      try {
        final otplessInstance = OtpService().otplessInstance;
        if (otplessInstance == null) {
          if (mounted) {
            setState(() {
              isError = true;
              loadingVerify = false;
            });
          }
          return;
        }
        final Map<String, dynamic> args = {
          "phone": widget.phoneNumber,
          "countryCode": "+91",
          "otp": otpTextController.text,
        };
        otplessDebugLog(
            'verifyOtp Otpless start otpLen=${otpTextController.text.length}');
        otplessInstance.start(onOtplessResponse, args);
      } catch (e) {
        otplessDebugLog('verifyOtp OTPless error: $e');
        if (mounted) {
          setState(() {
            isError = true;
            loadingVerify = false;
          });
        }
      }
    } else {
      try {
        final response = await LoginHttp.verifyOtp(data: {
          "phone": widget.phoneNumber,
          "otp": otpTextController.text,
        });

        if (response?.statusCode == 200) {
          final data = response?.data;
          final accessToken = data?[AppStrings.accessToken];
          if (accessToken != null) {
            await SecureStorageUtils.saveAccessToken(accessToken);
            await NetworkChannel.pushTokenAfterLogin(accessToken);
            final prefs = await SharedPreferences.getInstance();
            bool? cleverTapAccountExists =
                prefs.getBool(AppStrings.cleverTapAccountExists);
            if (cleverTapAccountExists != true) {
              await ClevertapSetup.logEvent(TrackingEvents.loginOtpVerified, {
                'action': "verify otp button clicked",
              });
            }
            OnboardingAnalytics.logEvent(
                TrackingEvents.otpVerificationSuccess, {
              ..._otpEventBaseProps(),
              'otp_entry_method': _otpFilledByAutoRead ? 'auto_read' : 'manual',
            });
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, SelectLanguageV2.routeName, (route) => false);
            }
            return;
          }
        }
        _otpAttemptCount += 1;
        OnboardingAnalytics.logEvent(TrackingEvents.otpVerificationFailed, {
          ..._otpEventBaseProps(),
          'error_type': response?.statusCode == 200
              ? 'http_200_no_token'
              : 'http_${response?.statusCode ?? 'unknown'}',
          'attempt_count': _otpAttemptCount,
          'error_copy': 'Incorrect OTP entered. Please enter again',
        });
        if (mounted) {
          setState(() {
            isError = true;
            loadingVerify = false;
          });
        }
      } catch (e) {
        otplessDebugLog('verifyOtp Edumarc error: $e');
        _otpAttemptCount += 1;
        OnboardingAnalytics.logEvent(TrackingEvents.otpVerificationFailed, {
          ..._otpEventBaseProps(),
          'error_type': 'network_error',
          'attempt_count': _otpAttemptCount,
          'error_copy': 'Incorrect OTP entered. Please enter again',
        });
        if (mounted) {
          setState(() {
            isError = true;
            loadingVerify = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    if (!widget.isOtpless) {
      _smsSubscription?.cancel();
      SmsAutoFill().unregisterListener();
    } else {
      unawaited(OtpService().restoreDefaultOtplessResponseCallback());
    }
    otpTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 50,
      textStyle:
          Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.n50),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.n40),
        borderRadius: BorderRadius.circular(10),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.brand),
      borderRadius: BorderRadius.circular(10),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: AppColors.n80,
      ),
    );
    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: AppColors.r50),
      ),
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: AppColors.n80,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            setState(() {});
          },
          child: Text(
            "OTP Verification",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontSize: 16),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.n80,
          ),
        ),
      ),
      persistentFooterAlignment: AlignmentDirectional.bottomCenter,
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: otpTextController.text.length >= 4 && !loadingVerify
                ? () async {
                    OnboardingAnalytics.logEvent(
                        TrackingEvents.otpScreenCtaClick, {
                      ..._otpEventBaseProps(),
                      'source': 'phone_number_screen',
                      'otp_entry_method':
                          _otpFilledByAutoRead ? 'auto_read' : 'manual',
                    });
                    await verifyOtp();
                  }
                : null,
            child: loadingVerify
                ? const CupertinoActivityIndicator(
                    color: AppColors.n0,
                  )
                : const Text(
                    "Confirm",
                  ),
          ),
        ),
      ],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Enter OTP sent to +91${widget.phoneNumber}",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (FrontendPreview.enabled) ...[
                    SizedBox(height: 8.h),
                    Text(
                      'Frontend preview: any 4 digits will continue',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.n70),
                    ),
                  ],
                  SizedBox(height: 24.h),
                  Pinput(
                    isCursorAnimationEnabled: false,
                    cursor: Text(
                      "0",
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.n50),
                    ),
                    controller: otpTextController,
                    preFilledWidget: Text(
                      "0",
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.n50),
                    ),
                    errorBuilder: (String? errorText, String pin) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(errorText ?? "",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: AppColors.r50)),
                        ),
                      );
                    },
                    mainAxisAlignment: MainAxisAlignment.center,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    submittedPinTheme:
                        isError ? errorPinTheme : submittedPinTheme,
                    errorPinTheme: errorPinTheme,
                    length: 4,
                    pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                    showCursor: true,
                    onChanged: (value) {
                      if (isError) {
                        isError = false;
                      }
                      if (_otpFilledByAutoRead && value != codeValue) {
                        _otpFilledByAutoRead = false;
                      }
                      setState(() {});
                    },
                  ),
                  Gap.gap8h,
                  if (isError && otpTextController.text.length == 4)
                    Text(
                      "Incorrect OTP entered. Please enter again",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.r50,
                          ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                if (counter <= 0)
                  loadingResendOtp
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: LinearProgressIndicator(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(16),
                            backgroundColor: Colors.transparent,
                          ),
                        )
                      : widget.isOtpless &&
                              (GlobalState()
                                      .appConfig
                                      ?.otplessApplicableChannels
                                      ?.isNotEmpty ??
                                  false)
                          ? Column(
                              children: [
                                Text(
                                  "Resend OTP via",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(color: AppColors.n70),
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: _buildChannelButtons(),
                                ),
                              ],
                            )
                          : TextButton(
                              onPressed: () async {
                                OnboardingAnalytics.incrementResendCount();
                                OnboardingAnalytics.logEvent(
                                    TrackingEvents.otpResendCtaClick, {
                                  ..._otpEventBaseProps(),
                                });
                                await SmsAutoFill().unregisterListener();
                                await SmsAutoFill().listenForCode();
                                setState(() {
                                  loadingResendOtp = true;
                                });
                                // Android SmsRetriever is one-shot — the
                                // listener armed in initPlatformState is
                                // already consumed by the first SMS. Re-arm
                                // before requesting the resend so the second
                                // SMS lands in an active 5-minute window.
                                await SmsAutoFill().listenForCode();
                                sendOtp().then((_) {
                                  if (otpResent) {
                                    _resetTimer();
                                  } else {
                                    if (context.mounted) {
                                      showSnackbar(context,
                                          "Send OTP failed. Please try again!");
                                    }
                                  }
                                });
                              },
                              child: Text(
                                "Resend OTP",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: AppColors.n90),
                              ),
                            ),
                if (counter > 0)
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: "Resend OTP in",
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: AppColors.n70)),
                      const WidgetSpan(child: SizedBox(width: 8)),
                      TextSpan(
                        text: "00:${counter.toString().padLeft(2, '0')}",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ]),
                  ),
              ],
            ),
            SizedBox(
              height: 26.h,
            ),
          ],
        ),
      ),
    );
  }
}

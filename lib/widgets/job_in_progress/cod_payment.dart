import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/go_live/text_divider.dart';
import 'package:snabbit_runner/widgets/job_in_progress/on_the_job.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../providers/language_provider.dart';
import '../../providers/runner_rt_data.dart';
import '../../services/clevertap.dart';
import '../../services/job_http.dart';
import '../../utils/colors.dart';
import '../../utils/tracking_events.dart';
import '../support_popup.dart';

class CODPayment extends StatefulWidget {
  const CODPayment({super.key});

  @override
  State<CODPayment> createState() => CODPaymentState();
}

class CODPaymentState extends State<CODPayment> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late OnTheJobStateProvider onTheJobStateProvider;
  String? error;
  String? paymentProvider;
  String? instrument;
  String? paymentStatus;
  Timer? timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onTheJobStateProvider =
          Provider.of<OnTheJobStateProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> initProcess() async {
    Response? response = await JobHttp.initiatePayment(
        jobId: runnerRtDataProvider.widgetInfo?.data?['job_id'],
        data: {"instrument": "QR"});
    if (response != null && response.statusCode == 200) {
      error = null;
      // data = response.data;
      paymentProvider = response.data?["provider"];
      instrument = response.data?["instrument"];
      paymentStatus = response.data?['status'];
      try {
        onTheJobStateProvider.qrImageData = response.data?["payment_data"]
            ["body"]["data"]["instrumentResponse"]["qrData"];
      } catch (e) {
        onTheJobStateProvider.qrImageData = null;
      }
      if (timer?.isActive != true) {
        timer = Timer.periodic(const Duration(seconds: 5), (t) async {
          await pollPaymentConfirmation();
          onTheJobStateProvider.pollingCounter =
              onTheJobStateProvider.pollingCounter - 1;
          if (onTheJobStateProvider.pollingCounter <= 0) {
            t.cancel();
            if (onTheJobStateProvider.pollingCounter == 0) {
              onTheJobStateProvider.currentState = OnTheJobState.qrFailed;
            }
          }
        });
      }
    } else {
      error = "${response?.data ?? "Something went wrong. Please try again!"}";
    }

    await ClevertapSetup.logEvent(TrackingEvents.qrCodePaymentModeSelected, {
      'action': "qr code payment mode selected at check out",
    });
  }

  Future<void> pollPaymentConfirmation() async {
    Response? response = await JobHttp.confirmPayment(
        jobId: runnerRtDataProvider.widgetInfo?.data?["job_id"] ?? -1,
        data: {
          'payment_provider': paymentProvider,
          'instrument': instrument,
        });
    // Logger().e("I am here ${response?.statusCode}");
    if (response != null && response.statusCode == 200) {
      error = null;
      paymentStatus = response.data?['status'];

      // Logger().d("state ${rdata}");
      // Logger().d("state ${rdata["status"]}");
      if (paymentStatus == "SUCCESS") {
        onTheJobStateProvider.pollingCounter = -1;
        onTheJobStateProvider.currentState = OnTheJobState.qrSuccessful;
      } else if (paymentStatus == "FAILED") {
        // Check if this is a "not yet attempted" error vs genuine failure
        final paymentData = response.data?['payment_data'];
        final errorMessage =
            paymentData?['error']?.toString().toLowerCase() ?? '';

        // If error indicates no payment attempt yet, treat as PENDING
        // an actual payment attempt was made
        final isNotYetAttempted = errorMessage
            .contains('no success, pending, or cod_initiated payment found');

        if (isNotYetAttempted) {
          // Treat as PENDING - continue polling
          // Do nothing, let polling continue
        } else {
          // Genuine failure - stop polling and show error
          onTheJobStateProvider.pollingCounter = -1;
          onTheJobStateProvider.currentState = OnTheJobState.qrFailed;
        }
      } else {
        // still PENDING
      }
    } else {
      error = "${response?.data ?? "Something went wrong. Please try again!"}";
    }
  }

  Widget get mainWidget {
    switch (onTheJobStateProvider.currentState) {
      case OnTheJobState.qrSuccessful:
        return SizedBox(
          width: 1.sw,
          child: Column(
            children: [
              Text(
                "${runnerRtDataProvider.widgetInfo?.data?["customer_name"] ?? "Snabbit Customer"}",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: AppColors.brand),
              ),
              Text(
                "₹ ${runnerRtDataProvider.widgetInfo?.data?['cash_amount']}",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(fontSize: 32.sp, color: AppColors.n90),
              ),
              SizedBox(height: 17.h),
              Divider(
                height: 1.r,
                color: AppColors.n30,
              ),
              SizedBox(height: 36.h),
              Container(
                width: 48.r,
                height: 48.r,
                decoration: const BoxDecoration(
                  color: AppColors.g40,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(6.r),
                child: FittedBox(
                  child: Icon(
                    Icons.check,
                    color: AppColors.n0,
                    size: 20.r,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                "${languageProvider.getMessage(
                  'payment_mode',
                  'Payment mode',
                )}: QR",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.n80,
                    ),
              ),
              SizedBox(height: 4.h),
              Text(
                languageProvider.getMessage(
                  'payment_collected',
                  'Payment Collected',
                ),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.g40,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        );
      case OnTheJobState.qrFailed:
        return SizedBox(
          width: 1.sw,
          child: Column(
            children: [
              Text(
                "${runnerRtDataProvider.widgetInfo?.data?["customer_name"] ?? "Snabbit Customer"}",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: AppColors.brand),
              ),
              Text(
                "₹ ${runnerRtDataProvider.widgetInfo?.data?['cash_amount']}",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(fontSize: 32.sp, color: AppColors.n90),
              ),
              SizedBox(height: 17.h),
              Divider(
                height: 1.r,
                color: AppColors.n30,
              ),
              SizedBox(height: 36.h),
              Container(
                width: 48.r,
                height: 48.r,
                decoration: const BoxDecoration(
                  color: AppColors.r40,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(6.r),
                child: FittedBox(
                  child: Icon(
                    Icons.close,
                    color: AppColors.n0,
                    size: 20.r,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                "${languageProvider.getMessage(
                  'payment_mode',
                  'Payment mode',
                )}: QR",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.n80,
                    ),
              ),
              SizedBox(height: 4.h),
              Text(
                languageProvider.getMessage(
                  'payment_failed',
                  'Payment Failed',
                ),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.r40,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: 1.sw,
                child: OutlinedButton(
                  onPressed: () async {
                    setState(() {
                      loading = true;
                    });
                    onTheJobStateProvider.currentState = OnTheJobState.qrOrCash;
                    onTheJobStateProvider.resetPollingCounter();
                    await initProcess();
                    setState(() {
                      loading = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.n80,
                    side: const BorderSide(color: AppColors.n60),
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      "retry_via_qr",
                      "Retry via QR",
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        height: 1.h,
                        color: AppColors.n60,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Text(
                        languageProvider.getMessage(
                          'or_capital',
                          'OR',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        height: 1.h,
                        color: AppColors.n60,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: () {
                    showCashCollectionPopup(context);
                  },
                  child: Text(
                    languageProvider.getMessage(
                      'collect_via_cash',
                      'Collect via Cash',
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Text(
                "${runnerRtDataProvider.widgetInfo?.data?["customer_name"] ?? "Snabbit Customer"}",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: AppColors.brand),
              ),
              SizedBox(height: 12.h),
              Text(
                languageProvider.getMessage(
                  "collect_payment",
                  "Collect payment",
                ),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 14.sp, color: AppColors.n70),
              ),
              SizedBox(height: 12.h),
              Text(
                "₹ ${runnerRtDataProvider.widgetInfo?.data?['cash_amount']}",
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(fontSize: 32.sp, color: AppColors.n90),
              ),
              SizedBox(height: 22.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: () {
                    showQrCollectionPopup(context);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RemoteImageHandler(
                        imageUrl: RemoteConfigAssets.collectViaQrIcon,
                        width: 20.w,
                        errorWidget: const SizedBox(),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        languageProvider.getMessage(
                          'collect_via_qr',
                          'Collect via QR',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
                child: AndDivider(
                  label: languageProvider.getMessage(
                    'or_capital',
                    'OR',
                  ),
                ),
              ),
              SizedBox(
                width: 1.sw,
                child: OutlinedButton(
                  onPressed: () {
                    // Navigator.pop(context);
                    // showCashCollect();
                    showCashCollectionPopup(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    side: const BorderSide(color: AppColors.brand),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RemoteImageHandler(
                        imageUrl: RemoteConfigAssets.collectViaCashIcon,
                        width: 20.w,
                        errorWidget: const SizedBox(),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        languageProvider.getMessage(
                          'collect_via_cash',
                          'Collect via Cash',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(
            child: CupertinoActivityIndicator(),
          )
        : mainWidget;
  }
}

void showCashCollectionPopup(BuildContext context) {
  showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) {
        return const CommonBottomSheetSetup(
          child: CashCollectionPopup(),
        );
      });
  ClevertapSetup.logEvent(TrackingEvents.cashPaymentModeSelected, {
    'action': "cash payment mode selected at check out",
  });
}

void showQrCollectionPopup(BuildContext context) {
  showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) {
        return const CommonBottomSheetSetup(
          child: QrCollectionPopup(),
        );
      }).then((_) async {
    try{
      if (context.mounted) {
        final onTheJobStateProvider = context.read<OnTheJobStateProvider>();
        if (onTheJobStateProvider.currentState == OnTheJobState.qrSuccessful) {
          final runnerRtDataProvider = context.read<RunnerRtDataProvider>();
          onTheJobStateProvider.pollingCounter = -1;
          if (runnerRtDataProvider.widgetInfo?.data?['show_checkout_otp'] ==
              true) {
            otpDialog(context);
          } else {
            await checkOutApi(
              jobId: runnerRtDataProvider.widgetInfo?.data?['job_id'] ?? -1,
              onSuccess: () {
                runnerRtDataProvider.fetchDataNow();
              },
            );
          }
        }
      }
    }catch(_){}
  });
  ClevertapSetup.logEvent(TrackingEvents.qrCodePaymentModeSelected, {
    'action': "qr code payment mode selected at check out",
  });
}

class CashCollectionPopup extends StatefulWidget {
  const CashCollectionPopup({super.key});

  @override
  State<CashCollectionPopup> createState() => _CashCollectionPopupState();
}

class _CashCollectionPopupState extends State<CashCollectionPopup> {
  bool init = true;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late OnTheJobStateProvider onTheJobStateProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onTheJobStateProvider =
          Provider.of<OnTheJobStateProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 36.h),
        Image.asset(
          AssetConstants.cashCollect,
          height: 60.h,
        ),
        SizedBox(height: 24.h),
        Text(
          languageProvider.getMessage(
            'please_collect',
            'Please Collect',
          ),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 22.h),
        Text(
          "₹ ${runnerRtDataProvider.widgetInfo?.data?['cash_amount']}",
          style: Theme.of(context)
              .textTheme
              .displayMedium
              ?.copyWith(fontSize: 32.sp, color: AppColors.n90),
        ),
        SizedBox(height: 36.h),
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // _launchDialer();
              onTheJobStateProvider.pollingCounter = -1;
              if (runnerRtDataProvider.widgetInfo?.data?['show_checkout_otp'] ==
                  true) {
                otpDialog(context);
              } else {
                await checkOutApi(
                  jobId: runnerRtDataProvider.widgetInfo?.data?['job_id'] ?? -1,
                  onSuccess: () {
                    runnerRtDataProvider.fetchDataNow();
                  },
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.g40,
            ),
            child: Text(
              languageProvider.getMessage(
                'i_have_collected_cash',
                'I have collected the cash',
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: 1.sw,
          child: OutlinedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return const CommonBottomSheetSetup(
                    child: SupportPopup(),
                  );
                },
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.n60),
              foregroundColor: AppColors.n80,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.call,
                  color: AppColors.n80,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  languageProvider.getMessage(
                    'call_support',
                    'Call support',
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: 1.sw,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.brand),
              foregroundColor: AppColors.brand,
            ),
            child: Text(
              languageProvider.getMessage(
                'go_back',
                'Go Back',
              ),
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }
}

class QrCollectionPopup extends StatefulWidget {
  const QrCollectionPopup({super.key});

  @override
  State<QrCollectionPopup> createState() => _QrCollectionPopupState();
}

class _QrCollectionPopupState extends State<QrCollectionPopup> {
  bool init = true;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;
  late OnTheJobStateProvider onTheJobStateProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onTheJobStateProvider =
          Provider.of<OnTheJobStateProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
    }

    // Auto-close modal when payment completes (success or failure)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (onTheJobStateProvider.currentState == OnTheJobState.qrSuccessful ||
          onTheJobStateProvider.currentState == OnTheJobState.qrFailed) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 36.h),
        Text(
          languageProvider.getMessage(
            'please_collect',
            'Please Collect',
          ),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.n70,
                fontSize: 16.sp,
              ),
        ),
        Text(
          "₹ ${runnerRtDataProvider.widgetInfo?.data?['cash_amount']}",
          style: Theme.of(context)
              .textTheme
              .displayMedium
              ?.copyWith(fontSize: 32.sp, color: AppColors.n90),
        ),
        if (onTheJobStateProvider.qrImageData != null)
          Image.memory(
            base64Decode(onTheJobStateProvider.qrImageData ?? ""),
            height: 185.r,
            errorBuilder: (_, __, ___) {
              return const SizedBox();
            },
          )
        else
          RemoteImageHandler(
            imageUrl: RemoteConfigAssets.qrLoadingState,
            width: 185.r,
            errorWidget: const SizedBox(),
          ),
        Text(
          languageProvider.getMessage(
            'request_customer_to_scan_qr',
            'Request customer to scan QR above',
          ),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppColors.n70),
        ),
        SizedBox(height: 36.h),
        SizedBox(
          width: 1.sw,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.brand),
              foregroundColor: AppColors.brand,
            ),
            child: Text(
              languageProvider.getMessage(
                'go_back',
                'Go Back',
              ),
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }
}

import 'package:comm_stream/comm_stream.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/constants.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/referral.dart';
import '../../widgets/payout/current_period_view.dart';
import '../pages/referral_contacts.dart';

class AddReferral extends StatefulWidget {
  final ReferralShiftType? referralShiftType;
  final int? daysOfValidity;
  final String? source;
  final String? referralText;
  const AddReferral({
    super.key,
    this.referralShiftType,
    this.source,
    this.daysOfValidity,
    this.referralText,
  });

  @override
  State<AddReferral> createState() => _AddReferralState();
}

class _AddReferralState extends State<AddReferral> {
  bool init = true;
  bool loading = false;
  String? error;
  bool isReferralSuccessful = false;
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  late LanguageProvider languageProvider;
  late ReferralDataProvider referralDataProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  bool permissionDenied = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);
      ClevertapSetup.logEvent(TrackingEvents.addReferralSheetViewed, {
        'type': widget.referralShiftType?.key,
        'source': widget.source,
      });
    }
    super.didChangeDependencies();
  }

  bool isSubmitAvailable() {
    try {
      return nameController.text.trim().isNotEmpty &&
          phoneController.text.trim().length == 10;
    } catch (e) {
      return false;
    }
  }

  Future<void> addReferral() async {
    try {
      ClevertapSetup.logEvent(TrackingEvents.referralSubmitted, {
        'type': widget.referralShiftType?.key,
        'source': widget.source,
      });
      Response? response = await RunnerHttp.runnerAddReferral(
        data: {
          'referral_name': nameController.text.trim(),
          'referral_phone_number': phoneController.text.trim(),
          'referral_shift_type': widget.referralShiftType?.key,
        },
      );
      if (response != null && response.statusCode == 200) {
        error = null;
        isReferralSuccessful = true;
        setState(() {});
        referralDataProvider.getReferrals(queryParameters: {
          'from_date': dateFormat.format(currentPeriodProvider.monthStartDate),
          'to_date': dateFormat.format(currentPeriodProvider.monthEndDate),
        });
      } else {
        String? serverError = response?.data['errors'][0]['message'];
        if (serverError != null) {
          error = serverError;
        } else {
          error = "Server error - ${response?.statusCode}";
        }
      }
    } catch (e) {
      error = "Something went wrong - $e";
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: CommonBottomSheetSetup(
        child: loading
            ? SizedBox(
                height: 0.2.sh,
                child: const Center(
                  child: CupertinoActivityIndicator(),
                ),
              )
            : isReferralSuccessful
                ? Column(
                    children: [
                      SizedBox(height: 30.h),
                      Container(
                        width: 81.r,
                        height: 81.r,
                        padding: EdgeInsets.all(15.r),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.g40,
                        ),
                        child: FittedBox(
                            child: Icon(
                          Icons.check_rounded,
                          size: 60.sp,
                          color: AppColors.n0,
                        )),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.h),
                        child: Text(
                          widget.referralShiftType == null
                              ? languageProvider.getMessage(
                                  "referral_successful",
                                  "Referral Received",
                                )
                              : "${widget.referralShiftType?.displayText(languageProvider)} ${languageProvider.getMessage(
                                  "Sent",
                                  "Sent",
                                )}",
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (nameController.text.trim().isNotEmpty)
                            FittedBox(
                              child: Text(
                                languageProvider.getFormattedMessage(
                                    "please_call_expert_now_and_inform",
                                    "Please call {{expert}} now and inform.",
                                    {'expert': nameController.text}),
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (widget.daysOfValidity != null &&
                              widget.daysOfValidity != 0)
                            FittedBox(
                              child: Text(
                                languageProvider.getFormattedMessage(
                                    "your_referral_is_valid_for_x_days",
                                    "Your referral is valid for {{days_of_validity}} days",
                                    {
                                      'days_of_validity': widget.daysOfValidity
                                    }),
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            )
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 16.h,
                        ),
                        child: Column(
                          children: [
                            ElevatedButton(
                              onPressed: _openDialer,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.call,
                                    color: AppColors.n0,
                                  ),
                                  SizedBox(
                                    width: 4.w,
                                  ),
                                  Flexible(
                                    child: FittedBox(
                                      child: Text(languageProvider
                                          .getFormattedMessage(
                                              "call_expert",
                                              "Call {{expert}}",
                                              {'expert': nameController.text})),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 8.h,
                            ),
                            OutlinedButton(
                              onPressed: _shareOnWhatsApp,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Color(0xFF1D2129),
                                  side: BorderSide(
                                    color: Color(0xFFD8DAE5),
                                    width: 1.r,
                                    style: BorderStyle.solid,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  )),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  RemoteImageHandler(
                                    imageUrl: RemoteConfigAssets
                                        .referralInformOnWhatsapp,
                                    height: 20.r,
                                    errorWidget: SizedBox(),
                                  ),
                                  SizedBox(
                                    width: 4.w,
                                  ),
                                  Flexible(
                                    child: FittedBox(
                                      child: Text(languageProvider.getMessage(
                                        "inform_on_whatsapp",
                                        "Inform on whatsapp",
                                      )),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(height: 22.h),
                      Padding(
                        padding: EdgeInsets.only(bottom: 20.h),
                        child: Text(
                          widget.referralShiftType
                                  ?.displayText(languageProvider) ??
                              '',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          // First request contacts permission
                          final contactsStatus =
                              await Permission.contacts.request();

                          // Then, in the same flow, request microphone/record permission.
                          await Permission.microphone.request();

                          if (contactsStatus.isGranted && context.mounted) {
                            Navigator.of(context).pushReplacementNamed(
                                ReferralContacts.routeName);
                          } else if (contactsStatus.isPermanentlyDenied) {
                            setState(() {
                              permissionDenied = true;
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.g40,
                          side: const BorderSide(color: AppColors.g40),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              languageProvider.getMessage(
                                  'view_phonebook', 'View phonebook'),
                            ),
                            SizedBox(width: 8.w),
                            const Icon(Icons.contacts_outlined),
                          ],
                        ),
                      ),
                      if (permissionDenied)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 8.h,
                          ),
                          child: Text(
                            languageProvider.getMessage(
                              'contacts_permission_denied_msg',
                              'Go to settings to allow contacts permission',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.r40),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Text(
                          languageProvider.getMessage(
                            "or",
                            "OR",
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: AppColors.n60),
                        ),
                      ),
                      TextField(
                        controller: nameController,
                        enabled: !loading,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) {
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: languageProvider.getMessage(
                              'enter_name', "Enter name"),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      TextField(
                        controller: phoneController,
                        enabled: !loading,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        onChanged: (_) {
                          setState(() {});
                        },
                        decoration: InputDecoration(
                            hintText: languageProvider.getMessage(
                                'enter_mobile_number', "Enter mobile number"),
                            counter: SizedBox()),
                      ),
                      if (error != null)
                        Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              error!,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: AppColors.r50),
                            ),
                          ),
                        ),
                      Container(
                        width: 1.sw,
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        child: ElevatedButton(
                          onPressed: isSubmitAvailable()
                              ? () async {
                                  setState(() {
                                    loading = true;
                                  });
                                  await addReferral();
                                  setState(() {
                                    loading = false;
                                  });
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.g40,
                          ),
                          child: Text(
                            languageProvider.getMessage(
                              "submit",
                              "Submit",
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  String get cleanNumber =>
      phoneController.text.replaceAll(RegExp(r'[^\d+]'), '');

  Future<void> _openDialer() async {
    try {
      final Uri telUri = Uri(
        scheme: 'tel',
        path: "+91$cleanNumber",
      );

      await CallUtils.handleCallInitiation(phoneNumber: cleanNumber,callSourceLabel: "ADD_REFERRAL", onSuccess: () async{
        await ClevertapSetup.logEvent(
            TrackingEvents.addReferralCallOptionClicked,
            {"action": "Open Dialer", "phone_number": cleanNumber});
      },
      onFailure: ({e,st}) {
        MonitoringServiceHelper.logError("COULD_NOT_OPEN_DIALER", {
          "source": "add_referral",
          "state": "success",
          "phone_number": cleanNumber,
          "error": e?.toString(),
          "stack_trace": st?.toString(),
        });
      },
      );
    } catch (_) {}
  }

  Future<void> _shareOnWhatsApp() async {
    try {
      String whatsappUrl = "https://wa.me/$cleanNumber";

      if (widget.referralText != null &&
          widget.referralText?.trim().isNotEmpty == true) {
        final encodedMessage = Uri.encodeComponent(widget.referralText ?? '');
        whatsappUrl += "?text=$encodedMessage";
      }

      final Uri uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        await ClevertapSetup.logEvent(
            TrackingEvents.addReferralWhatsAppOptionClicked,
            {"phone_number": cleanNumber});
      } else {
        MonitoringServiceHelper.logError("COULD_NOT_OPEN_DIALER", {
          "source": "add_referral",
          "state": "success",
          "phone_number": cleanNumber,
          "url": whatsappUrl,
        });
      }
    } catch (_) {}
  }
}

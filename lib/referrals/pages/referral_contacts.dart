import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/constants.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/referral.dart';
import '../services/referral_http.dart';

class ReferralContacts extends StatefulWidget {
  static const String routeName = "/referral-contacts";

  const ReferralContacts({super.key});

  @override
  State<ReferralContacts> createState() => _ReferralContactsState();
}

class _ReferralContactsState extends State<ReferralContacts> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  List<Contact> contactList = [];
  List<Contact> selectedContacts = [];
  bool isSelectionMode = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      initProcess().then((_) {
        loading = false;
        if (mounted) setState(() {});
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    Iterable<Contact> contacts =
        await FlutterContacts.getContacts(withProperties: true);
    contactList = contacts.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
      backgroundColor: const Color(0xffF5F6F8),
      persistentFooterButtons: [
        if (isSelectionMode)
          SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              onPressed: selectedContacts.isNotEmpty
                  ? () {
                      showModalBottomSheet(
                          context: context,
                          builder: (_) {
                            return CommonBottomSheetSetup(
                              child: ReferralSentBottomSheet(
                                contacts: selectedContacts,
                              ),
                            );
                          });
                    }
                  : null,
              child: Text(
                languageProvider.getMessage(
                  'refer_selected_contacts',
                  'Refer Selected Contacts',
                ),
              ),
            ),
          )
      ],
      body: loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : contactList.isEmpty
              ? const Center(
                  child: Text("No contacts found"),
                )
              : Padding(
                  padding: EdgeInsets.all(20.r),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              languageProvider.getMessage(
                                'refer_friends',
                                'Refer friends',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                      fontSize: 16.sp, color: AppColors.n90),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          if (isSelectionMode)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  isSelectionMode = false;
                                  selectedContacts.clear();
                                });
                              },
                              child: Text(
                                languageProvider.getMessage(
                                  'exit_selection',
                                  'Exit Selection',
                                ),
                              ),
                            )
                          else
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  isSelectionMode = true;
                                });
                              },
                              child: Text(
                                languageProvider.getMessage(
                                  'select',
                                  'Select',
                                ),
                              ),
                            ),
                        ],
                      ),
                      Flexible(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.n0,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 3.h),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20.r),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemBuilder: (_, index) {
                                try {
                                  final current = contactList[index];
                                  return SizedBox(
                                    width: 1.sw,
                                    child: ElevatedButton(
                                      onPressed: isSelectionMode
                                          ? () {
                                              setState(() {
                                                selectedContacts
                                                        .contains(current)
                                                    ? selectedContacts
                                                        .remove(current)
                                                    : selectedContacts
                                                        .add(current);
                                              });
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: AppColors.n90,
                                        backgroundColor: AppColors.n0,
                                        disabledBackgroundColor: AppColors.n0,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 19.h,
                                          horizontal: 12.w,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(0.r),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (isSelectionMode)
                                            Padding(
                                              padding:
                                                  EdgeInsets.only(right: 16.w),
                                              child: CircularCheckbox(
                                                squircle: true,
                                                iconSize: 14,
                                                circularCheckboxPadding: 3,
                                                value: selectedContacts
                                                    .contains(current),
                                              ),
                                            ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  current.displayName,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge,
                                                ),
                                                Text(
                                                  current.phones.first.number,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                          color: const Color(
                                                              0xff6D7783)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!isSelectionMode)
                                            SizedBox(
                                              height: 40.h,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  showModalBottomSheet(
                                                      context: context,
                                                      builder: (_) {
                                                        return CommonBottomSheetSetup(
                                                          child:
                                                              ReferralSentBottomSheet(
                                                            contacts: [current],
                                                          ),
                                                        );
                                                      });
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 12.w,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            1000.r),
                                                  ),
                                                ),
                                                child: Text(
                                                  languageProvider.getMessage(
                                                    'refer_now',
                                                    'Refer Now',
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                } catch (_) {
                                  return const SizedBox();
                                }
                              },
                              separatorBuilder: (_, __) => Divider(
                                color: const Color(0xFFD8DAE5),
                                height: 1.h,
                              ),
                              itemCount: contactList.length,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
    );
  }
}

class ReferralSentBottomSheet extends StatefulWidget {
  final List<Contact> contacts;

  const ReferralSentBottomSheet({super.key, required this.contacts});

  @override
  State<ReferralSentBottomSheet> createState() =>
      _ReferralSentBottomSheetState();
}

class _ReferralSentBottomSheetState extends State<ReferralSentBottomSheet> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  late ReferralDataProvider referralDataProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  String? error;
  bool isSuccess = false;
  bool isFailed = false;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: false);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: false);
      addReferral().then((_) {
        loading = false;
        if (mounted) setState(() {});
      });
    }
    super.didChangeDependencies();
  }

  Future<void> addReferral() async {
    try {
      isSuccess = false;
      final response = await RunnerHttp.runnerAddMultipleReferrals(
        data: {
          "referrals": widget.contacts.map((e) {
            try {
              return {
                'referral_name': e.displayName.trim(),
                'referral_phone_number': e.phones.first.number.trim(),
              };
            } catch (e) {
              return {};
            }
          }).toList()
        },
      );
      if (response != null && response.statusCode == 200) {
        error = null;
        isSuccess = true;
        setState(() {});
        referralDataProvider.getReferrals(queryParameters: {
          'from_date': dateFormat.format(currentPeriodProvider.monthStartDate),
          'to_date': dateFormat.format(currentPeriodProvider.monthEndDate),
        });
      } else {
        isFailed = true;
        try {
          error =
              ResponseError.fromMap(response?.data).getFirstError()?.message;
        } catch (err) {
          error = "Something went wrong - ${response?.statusCode}";
        }
      }
    } catch (e) {
      isFailed = true;
      error = "Something went wrong - $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? SizedBox(
            height: 0.25.sh,
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
          )
        : isSuccess
            ? Column(
                children: [
                  SizedBox(height: 54.5.h),
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
                  SizedBox(height: 24.h),
                  Text(
                    languageProvider.getMessage(
                      "referral_successful",
                      "Referral Sent",
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (widget.contacts.length > 1) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 22.h),
                      child: Text(
                        languageProvider.getMessage(
                          'multi_referral_success_subtitle',
                          'Please inform your friends now. Your referral is valid for 7 days',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    SizedBox(
                      width: 1.sw,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await ReferralHttp.remind(
                              data: {
                                "referrals": widget.contacts.map((e) {
                                  try {
                                    return {
                                      'referral_name': e.displayName.trim(),
                                      'referral_phone_number':
                                          e.phones.first.number.trim(),
                                    };
                                  } catch (e) {
                                    return {};
                                  }
                                }).toList()
                              },
                            );
                            showSnackbar(context, "Reminder sent");
                            Navigator.of(context).pop();
                          } catch (_) {}
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RemoteImageHandler(
                              imageUrl:
                                  "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/referrals/whatsapp_icon.svg",
                              height: 24.r,
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                languageProvider.getMessage(
                                  'inform_on_wa',
                                  'Inform on whatsapp',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (widget.contacts.length == 1) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 22.h),
                      child: Text(
                        languageProvider.getFormattedMessage(
                          'single_referral_success_subtitle',
                          'Please call {{referee_name}} now and inform. Your referral is valid for 7 days',
                          {
                            "referee_name": widget.contacts[0].displayName,
                          },
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    SizedBox(
                      width: 1.sw,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final phone =
                                widget.contacts[0].phones.first.number;
                            await CallUtils.handleCallInitiation(
                              phoneNumber: phone,
                              context: context,
                              callSourceLabel: "REFERRAL_CONTACTS",
                            );
                          } catch (_) {}
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.call),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                languageProvider.getFormattedMessage(
                                  'call_referee',
                                  'Call {{referee_name}}',
                                  {
                                    'referee_name':
                                        widget.contacts[0].displayName,
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: 1.sw,
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await ReferralHttp.remind(
                              data: {
                                "referrals": widget.contacts.map((e) {
                                  try {
                                    return {
                                      'referral_name': e.displayName.trim(),
                                      'referral_phone_number':
                                          e.phones.first.number.trim(),
                                    };
                                  } catch (e) {
                                    return {};
                                  }
                                }).toList()
                              },
                            );
                          } catch (_) {}
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.n90,
                          side: const BorderSide(color: AppColors.n40),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RemoteImageHandler(
                              imageUrl:
                                  "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/referrals/whatsapp_icon_black.svg",
                              height: 24.r,
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                languageProvider.getMessage(
                                  'inform_on_wa',
                                  'Inform on whatsapp',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              )
            : isFailed
                ? SizedBox(
                    height: 0.25.sh,
                    child: Center(child: Text(error ?? "Referral Failed")),
                  )
                : const SizedBox();
  }
}

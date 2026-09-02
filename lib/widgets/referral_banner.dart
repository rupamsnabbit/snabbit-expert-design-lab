import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:format/format.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/svg_strings.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/text_form.dart';
import 'package:url_launcher/url_launcher.dart';

class ReferralBanner extends StatefulWidget {
  const ReferralBanner({super.key});

  @override
  State<ReferralBanner> createState() => _ReferralBannerState();
}

class _ReferralBannerState extends State<ReferralBanner> {
  List<String> _bannerUrls = [];

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    try {
      // Routed through HttpService so the call is captured by the debug
      // network inspector (and carries standard auth headers).
      final response = await HttpService()
          .get(GlobalState().serverPath("api/v1/runners/promotions"));
      if (response.statusCode == 200) {
        setState(() {
          _bannerUrls = List<String>.from(response.data['banner_urls']);
        });
      }
    } catch (e) {
      print('Error fetching promotions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 3.h, left: 16.w, right: 16.w),
      child: InkWell(
        onTap: () async {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ReferralBannerPage()));

          await ClevertapSetup.logEvent(TrackingEvents.referralBannerClicked,
              {"referral_banner": "Referral banner clicked"});
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: _bannerUrls.isNotEmpty
              ? Image.network(
                  _bannerUrls.first,
                  height: 75,
                )
              : Container(),
        ),
      ),
    );
  }
}

class ReferralBannerPage extends StatefulWidget {
  const ReferralBannerPage({super.key});

  @override
  State<ReferralBannerPage> createState() => _ReferralBannerPageState();
}

class _ReferralBannerPageState extends State<ReferralBannerPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  Map<String, dynamic> referralDetails =
      {}; //{referral_amount: int, referral_text: string}

  late LanguageProvider languageProvider;
  bool init = true;
  bool loading = true;

  Future<void> fetchReferralDetails() async {
    // Routed through HttpService so the call is captured by the debug
    // network inspector (and carries standard auth headers).
    Response response = await HttpService()
        .get(GlobalState().serverPath("api/v1/runners/me/referral_details"));
    if (response.statusCode == 200) {
      setState(() {
        referralDetails = response.data;
      });
    } else {
      showSnackbar(context,
          "${response.data ?? "Something went wrong. Please try again!"}");
    }
  }

  Future<void> _shareOnWhatsApp() async {
    final encodedMessage =
        Uri.encodeComponent(referralDetails["referral_text"]);
    final whatsappUrl = "whatsapp://send?text=$encodedMessage";

    await launchUrl(Uri.parse(whatsappUrl));

    await ClevertapSetup.logEvent(TrackingEvents.referralBannerClicked, {
      "referral_banner": "Referral banner clicked",
      "link_shared": "Linked shared using whatsapp"
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      fetchReferralDetails().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 410.h,
                ),
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32.r),
                    bottomRight: Radius.circular(32.r),
                  ),
                  child: Image.asset(
                    "assets/referral_page_bg.png",
                    height: 390.h,
                  ),
                ),
                Container(
                  color: Colors.black45,
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                  child: Column(
                    children: [
                      Text(
                        languageProvider
                            .getMessage("refer_friend_earn_cash_msg",
                                "Earn ₹${referralDetails["referral_amount"] ?? 2000} for every friend who joins Snabbit")
                            .format({
                          #referral_cash_amount:
                              "${referralDetails["referral_amount"]}"
                        }),

                        // "Earn ₹${referralDetails["referral_amount"] ?? 2000} for every friend who joins Snabbit",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.n0,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        languageProvider.getMessage("refer_friend_relative_msg",
                            'Refer your friend, relative or neighbour and earn for every successful joining'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.n0,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Positioned(
                //   bottom: 0,
                //   left: 0,
                //   right: 0,
                //   child: Center(
                //     child: FloatingActionButton.extended(
                //       backgroundColor: AppColors.n0,
                //       onPressed: () {},
                //       label: Padding(
                //         padding: EdgeInsets.symmetric(horizontal: 16.w),
                //         child: Column(
                //           children: [
                //             const Text("🎉 Earned So Far"),
                //             Text(
                //               "₹9,000",
                //               style: TextStyle(
                //                   fontSize: 24.sp, fontWeight: FontWeight.bold),
                //             ),
                //           ],
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
            SizedBox(
              height: 8.h,
            ),
            Padding(
              padding: EdgeInsets.all(24.r),
              child: FloatingActionButton.extended(
                onPressed: _shareOnWhatsApp,
                backgroundColor: const Color(0xff40C351),
                label: Row(
                  children: [
                    SvgPicture.asset(SvgStrings.whatsapp),
                    SizedBox(
                      width: 8.w,
                    ),
                    Text(
                      languageProvider.getMessage(
                          "share_link_whatsapp", 'Share link via Whatsapp'),
                      style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.n0),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: const Divider(
                color: AppColors.n40,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.0),
              child: TextFormSnabbit(
                controller: nameController,
                hintText: 'Enter Friend\'s Name',
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.0),
              child: TextFormSnabbit(
                controller: phoneController,
                hintText: 'Enter Phone Number',
                keyboardType: TextInputType.phone,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(24.r),
              child: FloatingActionButton.extended(
                onPressed: () async {
                  Map<String, dynamic>? data = {};
                  if (phoneController.text.trim().isNotEmpty) {
                    if (phoneController.text.trim().length != 10 ||
                        nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Please enter friends\'s name & a valid 10-digit phone number')),
                      );
                      return;
                    }

                    data = {
                      "contact": {
                        "name": nameController.text.trim(),
                        "phones": [phoneController.text.trim()]
                      },
                      "visited": false
                    };
                  }

                  final prefs = await SharedPreferences.getInstance();
                  String? token = prefs.getString(AppStrings.accessToken);
                  Logger().i("token: $token");
                  Response? response =
                      await RunnerHttp.runnerReferral(data: data);

                  if (response != null && response.statusCode == 200) {
                    refer();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Something went wrong')),
                    );
                  }

                  await ClevertapSetup.logEvent(
                      TrackingEvents.referralBannerClicked,
                      {"referral_banner": "refer button clicked"});
                },
                backgroundColor: const Color(0xff3030D6),
                label: Text(
                  languageProvider.getMessage("refer", "Refer"),
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.n0),
                ),
              ),
            ),
            SizedBox(
              height: 24.h,
            )
          ],
        ),
      ),
    );
  }

  refer() {
    Timer? timer;
    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      Navigator.of(context).pop();
      timer?.cancel();
    });
    showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16.r),
          ),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.2,
        ),
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setStateBottomSheet) {
            return Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        languageProvider.getMessage("thankyou_for_referral_msg",
                            "Thank You! When your friend joins, you will be rewarded"),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    width: 48.r,
                    height: 48.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.g40,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.n0,
                      size: 28.sp,
                    ),
                  )
                ],
              ),
            );
          });
        }).then((_) {
      Navigator.pop(context);
      timer?.cancel();
    });
  }
}

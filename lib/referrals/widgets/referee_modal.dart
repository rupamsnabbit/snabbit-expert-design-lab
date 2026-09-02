import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../services/referral_http.dart';

class Referrer {
  int? amount;
  String? name;
  String? phone;
  String? image;

  Referrer({
    this.amount,
    this.name,
    this.phone,
    this.image,
  });

  factory Referrer.fromJson(Map<String, dynamic> json) {
    return Referrer(
      amount: anyValueToInt(json['amount']),
      name: json['name'],
      phone: json['phone'],
      image: json['image'] ?? AssetConstants.avatarImagePlaceholder,
    );
  }
}

void showRefereeBottomSheet() async {
  try {
    final context = GlobalState().navigatorKey.currentContext!;
    final response = await ReferralHttp.getRefereeDetails();
    if (response?.statusCode == 200 && context.mounted) {
      final referrer = Referrer.fromJson(response!.data);
      ReferralHttp.referrerCardShown();
      showModalBottomSheet(
          context: context,
          builder: (_) {
            return CommonBottomSheetSetup(
              showDragHandle: false,
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF7967C8), // #7967C8
                  Color(0xFF434893), // #434893
                ],
                stops: [0.0, 1.0], // 0% → 100%
              ),
              child: RefereeModal(
                referrer: referrer,
              ),
            );
          });
    }
  } catch (_) {}
}

class RefereeModal extends StatefulWidget {
  final Referrer referrer;

  const RefereeModal({
    super.key,
    required this.referrer,
  });

  @override
  State<RefereeModal> createState() => _RefereeModalState();
}

class _RefereeModalState extends State<RefereeModal> {
  bool init = true;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1.sw,
      child: Column(
        children: [
          Stack(
            children: [
              RemoteImageHandler(
                imageUrl:
                    "https://snabbit-assets.s3.ap-south-1.amazonaws.com/expert_app/referrals/referee_bg.png",
                width: 1.sw,
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppColors.n0,
                        fontSize: 36.sp,
                        fontWeight: FontWeight.w500,
                        height: 28 / 36,
                        // line-height ratio
                        letterSpacing: -0.24,
                        shadows: [
                          const Shadow(
                            offset: Offset(0, 4),
                            blurRadius: 4,
                            color:
                                Color.fromRGBO(90, 15, 49, 0.4), // text-shadow
                          ),
                        ],
                      ),
                      children: [
                        TextSpan(
                          text: "₹${widget.referrer.amount}",
                          style: const TextStyle(
                            color: Color(0xFFFBBC05), // Gold override
                            fontWeight: FontWeight.w700, // Bold override
                          ),
                        ),
                        TextSpan(
                          text: " ${languageProvider.getMessage(
                            'earned',
                            'Earned',
                          )}",
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            width: 1.sw,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF8B7DCF), // #8B7DCF
                  Color(0xFF5256AD), // #5256AD
                ],
                stops: [0.0, 1.0],
              ),
            ),
            child: Column(
              children: [
                Text(
                  languageProvider.getMessage(
                    'referred_by_buddy',
                    'You were referred by your buddy',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.n0),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Divider(
                    height: 1.h,
                    color: AppColors.n0,
                  ),
                ),
                Row(
                  children: [
                    RemoteImageHandler(
                      imageUrl: widget.referrer.image ?? "",
                      height: 36.r,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.referrer.name ?? "",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: AppColors.n0),
                          ),
                          Text(
                            widget.referrer.phone ?? "",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.n0,
                                  fontSize: 11.sp,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 31.h),
          SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.n0,
                foregroundColor: AppColors.n90,
              ),
              child: Text(
                languageProvider.getMessage(
                  'get_started',
                  'Get Started',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

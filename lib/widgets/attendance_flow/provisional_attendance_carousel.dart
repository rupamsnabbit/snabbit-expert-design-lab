import 'package:carousel_slider/carousel_slider.dart';
import 'package:comm_stream/ui/widgets/remote_image_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_bank_or_upi_details_screen.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/attendance_flow/ming_eligibility_info.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_add_details_banner.dart';
import 'package:snabbit_runner/widgets/payout/add_bank_banner.dart';
import 'package:snabbit_runner/widgets/upload_documents/upload_pan_modal_sheet_v2.dart';

class ProvisionalAttendanceCarousel extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const ProvisionalAttendanceCarousel({
    super.key,
    this.widgetData,
  });

  @override
  State<ProvisionalAttendanceCarousel> createState() =>
      _ProvisionalAttendanceCarouselState();
}

class _ProvisionalAttendanceCarouselState
    extends State<ProvisionalAttendanceCarousel> {
  bool init = true;

  int _currentCarouselIndex = 0;

  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
    }
  }

  bool get isBankVerified => userProfileProvider.user?.bankVerified == true;

  bool get isBankDetailsFilled =>
      userProfileProvider.user?.bankAccountNumber?.isNotEmpty == true;

  bool get isPanVerified => userProfileProvider.user?.isPanVerified == true;

  bool get isPanAadharLinked =>
      userProfileProvider.user?.panAadharLinked == true;

  bool get isPanUnavailable =>
      userProfileProvider.user?.panCardUnavailable == true;

  bool _shouldShowCarousel() {
    // Check if any carousel items will be shown
    return widget.widgetData?['ming_banner'] != null ||
        !isBankVerified ||
        !isPanVerified ||
        !isPanAadharLinked;
  }

  Widget _buildCarouselIndicators() {
    // Count the number of banners that will be shown
    int bannerCount = 0;

    // Check each condition that adds a banner
    if (!isBankVerified) bannerCount++;
    if (!isPanVerified) bannerCount++;
    if (!isPanAadharLinked) bannerCount++;
    if (widget.widgetData?['ming_banner'] != null) bannerCount++;

    if (bannerCount <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        bannerCount,
        (index) => Container(
          width: 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentCarouselIndex == index
                ? AppColors.brand
                : AppColors.n40,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: const Divider(
            color: AppColors.n30,
          ),
        ),
        SizedBox(
          width: 1.sw,
          child: Column(
            children: [
              if (_shouldShowCarousel()) ...[
                CarouselSlider(
                  items: [
                    if (widget.widgetData?['ming_banner'] != null)
                      Container(
                        width: 1.sw,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: Stack(
                            children: [
                              // Background image
                              Positioned.fill(
                                child: RemoteImageHandler(
                                  imageUrl: widget.widgetData!['ming_banner']
                                              ['bg_image']
                                          ?.toString()
                                          .cdn ??
                                      '',
                                  fit: BoxFit.fitWidth,
                                ),
                              ),
                              Positioned(
                                right: 12.w,
                                top: 0,
                                bottom: 0,
                                child: RemoteImageHandler(
                                  imageUrl: widget.widgetData!['ming_banner']
                                              ['coins_image']
                                          ?.toString()
                                          .cdn ??
                                      '',
                                  width: 0.20.sw,
                                  // height: 100.h,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // Text content overlay
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 22.w, vertical: 8.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    FittedBox(
                                      child: Text(
                                        languageProvider.getMessage(
                                          widget.widgetData!['ming_banner']
                                                  ['title']?['key'] ??
                                              '',
                                          widget.widgetData!['ming_banner']
                                                  ['title']?['key'] ??
                                              '',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayMedium
                                            ?.copyWith(
                                              fontSize: 18.sp,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    FittedBox(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8.r, vertical: 4.r),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(16.r),
                                            topRight: Radius.circular(16.r),
                                          ),
                                          color: Colors.white.withOpacity(0.4),
                                        ),
                                        transform: Matrix4.skewX(-.1),
                                        child: RichText(
                                          textAlign: TextAlign.center,
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: widget.widgetData![
                                                            'ming_banner']
                                                        ['amount'] ??
                                                    '',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displayLarge
                                                    ?.copyWith(
                                                        color:
                                                            Color(0xFF421A2D),
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 32.sp),
                                              ),
                                              WidgetSpan(
                                                  child: SizedBox(width: 4.w)),
                                              TextSpan(
                                                text:
                                                    languageProvider.getMessage(
                                                  widget.widgetData![
                                                                  'ming_banner']
                                                              ['subtitle']
                                                          ?['key'] ??
                                                      '',
                                                  widget.widgetData![
                                                                  'ming_banner']
                                                              ['subtitle']
                                                          ?['key'] ??
                                                      '',
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displayMedium
                                                    ?.copyWith(
                                                        color:
                                                            Color(0xFF421A2D),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 17.sp),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!isBankVerified)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: SizedBox(
                          width: 0.8.sw,
                          child: AddBankBanner(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                  AddBankOrUpiDetailsScreen.routeName);
                            },
                            image: "",
                          ),
                        ),
                      ),
                    if (!isPanVerified)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: SizedBox(
                          width: 0.8.sw,
                          child: CustomAddDetailsBanner(
                            title: {
                              "key": "pan_card_benefit_text",
                              "text":
                                  "{{pan_card_highlight}} helps reduce Income Tax",
                              "style": {
                                "name": "Metropolis",
                                "font_size": 14,
                                "color": "#C50F1F",
                                "weight": 600,
                                "style": "normal"
                              },
                              "data": [
                                {
                                  "key": "pan_card_highlight",
                                  "text": "PAN Card",
                                  "style": {
                                    "name": "Metropolis",
                                    "font_size": 14,
                                    "color": "#C50F1F",
                                    "weight": 800,
                                    "style": "normal"
                                  }
                                }
                              ],
                              "alignment": "left"
                            },
                            image: RemoteConfigAssets.addPanIcon,
                            subtitle: languageProvider.getMessage(
                              'upload_now',
                              'Upload Now',
                            ),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (_) {
                                  return const UploadPanModalSheetV2();
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    if (!isPanAadharLinked)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: SizedBox(
                          width: 0.8.sw,
                          child: CustomAddDetailsBanner(
                            title: {
                              "key": "link_pan_aadhaar_benefit_text",
                              "text":
                                  "Link your {{pan_card_highlight}} with {{aadhaar_highlight}} to reduce Income Tax",
                              "style": {
                                "name": "Metropolis",
                                "font_size": 14,
                                "color": "#C50F1F",
                                "weight": 600,
                                "style": "normal"
                              },
                              "data": [
                                {
                                  "key": "pan_card_highlight",
                                  "text": "PAN Card",
                                  "style": {
                                    "name": "Metropolis",
                                    "font_size": 14,
                                    "color": "#C50F1F",
                                    "weight": 800,
                                    "style": "normal"
                                  }
                                },
                                {
                                  "key": "aadhaar_highlight",
                                  "text": "Aadhar",
                                  "style": {
                                    "name": "Metropolis",
                                    "font_size": 14,
                                    "color": "#C50F1F",
                                    "weight": 800,
                                    "style": "normal"
                                  }
                                }
                              ],
                              "alignment": "left"
                            },
                            image: RemoteConfigAssets.linkPanAadhaarIcon,
                          ),
                        ),
                      ),
                  ],
                  options: CarouselOptions(
                    height: 120.h,
                    viewportFraction: 1,
                    initialPage: 0,
                    enableInfiniteScroll: true,
                    reverse: false,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 4),
                    autoPlayAnimationDuration:
                        const Duration(milliseconds: 800),
                    autoPlayCurve: Curves.fastOutSlowIn,
                    enlargeCenterPage: false,
                    scrollDirection: Axis.horizontal,
                    padEnds: false,
                    onPageChanged: (index, reason) {
                      setState(() {
                        _currentCarouselIndex = index;
                      });
                    },
                  ),
                ),
                SizedBox(height: 16.h),
                _buildCarouselIndicators(),
              ],
            ],
          ),
        ),
        if (widget.widgetData?['is_ming_ineligible'] == true)
          MingEligibilityInfo(
            reasons: widget.widgetData?['ming_ineligibility_reasons'] ?? [],
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../../../services/payout_http.dart';
import '../models/festive_bonus.dart';
import '../pages/festive_bonus_screen.dart';

class FestiveJackpotBanner extends StatefulWidget {
  const FestiveJackpotBanner({super.key});

  @override
  State<FestiveJackpotBanner> createState() => _FestiveJackpotBannerState();
}

class _FestiveJackpotBannerState extends State<FestiveJackpotBanner> {
  bool loading = true;
  FestiveBanner? banner;

  @override
  void initState() {
    initProcess().then((_) {
      loading = false;
      if (mounted) setState(() {});
    });
    super.initState();
  }

  Future<void> initProcess() async {
    try {
      final response = await PayoutHttp.getFestiveBanner();
      if (response != null) {
        banner = FestiveBanner.fromJson(response.data);
      }
    } catch (e) {
      // DO NOTHING
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: loading
          ? const SizedBox()
          : banner == null
              ? const SizedBox()
              : GestureDetector(
                  onTap: () {
                    Navigator.of(context)
                        .pushNamed(FestiveBonusScreen.routeName);
                  },
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      RemoteImageHandler(
                        imageUrl: banner?.bgImage?.url ?? "",
                        fit: BoxFit.cover,
                        width: 1.sw,
                        errorWidget: Container(
                          width: 1.sw,
                          height: banner?.bgImage?.height?.h,
                          color: banner?.bgImage?.color,
                        ),
                      ),
                      if (banner != null)
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(13.w, 14.h, 15.w, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: CustomText(
                                            textData: banner?.title,
                                          ),
                                        ),
                                        if (banner?.subtitle != null)
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: CustomText(
                                              textData: banner?.subtitle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                CustomText(textData: banner?.value),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/insurance_profile.dart';
import 'package:snabbit_runner/providers/insurance_profile_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_text_highlighter.dart';
import 'dart:math' as math;

class CongratulatoryCard extends StatefulWidget {
  const CongratulatoryCard({super.key});

  @override
  State<CongratulatoryCard> createState() => _CongratulatoryCardState();
}

class _CongratulatoryCardState extends State<CongratulatoryCard> {
  late LanguageProvider languageProvider;
  late InsuranceProfileProvider insuranceProfileProvider;
  late UserProfileProvider userProfileProvider;
  bool isError = false;
  bool loading = false;
  bool init = true;

  Future<void> initProcess() async {
    loading = true;
    insuranceProfileProvider.fetchData();
  }

  CongratulatoryMessage? get congratulatoryMessage => insuranceProfileProvider
      .insuranceProfile?.tierBenefits?.congratulatoryMessage;

  DowngradeWarning? get downgradeWarning => insuranceProfileProvider
      .insuranceProfile?.qualifierInfo?.downgradeWarning;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      insuranceProfileProvider =
          Provider.of<InsuranceProfileProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      init = false;
      if (insuranceProfileProvider.insuranceProfile == null) {
        initProcess().then((_) {
          loading = false;
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading ||
        congratulatoryMessage == null ||
        downgradeWarning != null ||
        userProfileProvider.user?.tier != Tier.ELITE) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14.97.r),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            // CSS: 99deg. This approximates a gradient that starts slightly from bottom-left
            // and goes towards top-right, but mostly horizontally.
            begin: Alignment(-1.0, 0.1),
            end: Alignment(1.0, -0.1),
            colors: [
              Color(0xFFFFFFFF), // #FFF
              Color(0xFFEED38D), // #EED38D
            ],
            stops: [0.003, 0.997], // 0.3% and 99.7%
          ),
          borderRadius: BorderRadius.circular(14.97.r),
          border: Border.all(
            color: const Color(0xFFE9D091), // #602D0B
            width: 2.w, // Border width
          ),
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: 20.w, bottom: 13.h),
                    height: 136.h,
                    alignment: Alignment.bottomLeft,
                    child: CustomTextHighlighter(
                      text:
                          "${languageProvider.getMessage("congratulate_gold_expert", "Keep Up The Good Work")}\n{{GOLD EXPERT}}",
                      textStyle:
                          Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF602D0B),
                                fontSize: 16.sp,
                                fontStyle: FontStyle.normal,
                                height: 18 / 16,
                                // line-height / font-size
                                letterSpacing: -0.24,
                                // text-transform: capitalize; is a property of the Text widget itself,
                                // typically handled by String manipulation (e.g., .capitalize() if available,
                                // or a custom function) before passing to the Text widget.
                              ),
                      customHighlighter: (text) => ShaderMask(
                        // Define the linear gradient
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            // CSS: 90deg means from left to right
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            // CSS colors: #FFCA6E 0%, #A8593F 100%
                            colors: [
                              Color(0xFFFFCA6E), // Start color
                              Color(0xFFA8593F), // End color
                            ],
                            // Optional: stops can be used if your gradient has more precise stops
                            // stops: [0.0, 1.0],
                          ).createShader(
                              bounds); // Create the shader using the bounds of the text
                        },
                        // Use BlendMode.srcIn to apply the gradient only where the text pixels are opaque
                        // This mimics background-clip: text and -webkit-text-fill-color: transparent
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          text,
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontSize: 28.sp,
                                fontStyle: FontStyle.normal,
                                fontWeight: FontWeight.w700,
                                height: 28.432 / 28.0,
                                // line-height / font-size
                                letterSpacing: -0.379,
                              ),
                        ),
                      ),
                      // placeholder: "{{gold_expert}}"
                    ),
                  ),
                ),
                Image.network(
                  congratulatoryMessage?.image ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox
                        .shrink(); // Placeholder for image loading error
                  },
                  height: 125.h,
                )
              ],
            ),
            if (congratulatoryMessage?.gif != null)
              Positioned(
                top: -55,
                left: -50,
                child: Transform.rotate(
                  // CSS: transform: rotate(157.63deg);
                  // Convert degrees to radians for Flutter's Transform.rotate
                  angle: 157.63 * (math.pi / 180),
                  child: Image.network(
                    congratulatoryMessage?.gif ?? '',
                    width: 190.927,
                    // CSS: width: 190.927px;
                    height: 190.927,
                    // CSS: height: 190.927px;
                    fit: BoxFit.cover,
                    // Adjust as needed, BoxFit.cover fills the bounds
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback for when the image fails to load
                      return const SizedBox();
                    },
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

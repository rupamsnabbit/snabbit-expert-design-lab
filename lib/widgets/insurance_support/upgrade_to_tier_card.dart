import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/insurance_profile.dart';
import 'package:snabbit_runner/providers/insurance_profile_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_text_highlighter.dart';

class UpgradeToTierCard extends StatefulWidget {
  const UpgradeToTierCard({super.key});

  @override
  State<UpgradeToTierCard> createState() => _UpgradeToTierCardState();
}

class _UpgradeToTierCardState extends State<UpgradeToTierCard> {
  late LanguageProvider languageProvider;
  late InsuranceProfileProvider insuranceProfileProvider;
  bool isError = false;
  bool loading = false;
  bool init = true;

  Future<void> initProcess() async {
    loading = true;
    insuranceProfileProvider.fetchData();
  }

  TierUpgradeInfo? get tierUpgradeInfo =>
      insuranceProfileProvider.insuranceProfile?.tierBenefits?.tierUpgradeInfo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      insuranceProfileProvider =
          Provider.of<InsuranceProfileProvider>(context, listen: true);
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

  Tier? get nextTier =>
      insuranceProfileProvider.insuranceProfile?.qualifierInfo?.nextTier;

  Color? get _nextTierColor {
    switch (nextTier) {
      case Tier.PRO:
        return const Color(0xFF8874D8);
      case Tier.ELITE:
        return const Color(0xFFEAA10F);
      default:
        return null;
    }
  }

  Color? get _nextTierBorder {
    switch (nextTier) {
      case Tier.PRO:
        return const Color(0xFFBDCDD2);
      case Tier.ELITE:
        return const Color(0xFFF5D08A);
      default:
        return null;
    }
  }

  String? get _nextTierBadgeAsset {
    switch (nextTier) {
      case Tier.PRO:
        return AssetConstants.tierSilverBadge;
      case Tier.ELITE:
        return AssetConstants.tierGoldBadge;
      default:
        return null;
    }
  }

  List<Color> shaderColors() {
    if (nextTier == Tier.ELITE) {
      return const [Color(0xFFF39F33), Color(0xFFBE7A09)];
    } else if (nextTier == Tier.PRO) {
      return const [Color(0xFF8A81C4), Color(0xFF7862CD)];
    } else {
      return const [Colors.transparent, Colors.transparent];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading || tierUpgradeInfo == null || nextTier == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: AppColors.n0,
        border: Border.all(
            color: _nextTierBorder ?? Colors.transparent, width: 2.r),
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x21BCCAFF),
            blurRadius: 23.0.r,
            offset: Offset(0, 14.97.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Transform.translate(
                    offset: Offset(0, -520.h),
                    child: Container(
                      width: 609.w,
                      height: 609.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _nextTierColor!.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 14.h),
                  Image.asset(
                    _nextTierBadgeAsset!,
                    height: 55.r,
                    width: 55.r,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  SizedBox(height: 11.5.h),
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        colors: shaderColors(),
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds);
                    },
                    child: Text(
                      languageProvider.getFormattedMessage(
                          "upgrade_to_tier",
                          "Upgrade to {{next_tier}} Tier",
                          {'next_tier': nextTier?.normalizedDescription ?? ''}),
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1,
                                letterSpacing: -0.575876,
                                color: AppColors.n0,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.fromLTRB(23.w, 0, 21.w, 17.48.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...?tierUpgradeInfo?.conditionalPoints?.map(
                          (condition) => Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: _ChecklistItem(
                              isAchieved: condition.isAchieved ?? false,
                              text: getMessage(condition),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getMessage(ConditionalPoints condition) {
    String key = condition.name ?? '';
    dynamic value = condition.value;
    if (key == AppStrings.requiredAttendancePercentage) {
      return languageProvider.getFormattedMessage2(
        "upgrade_tier_attendance",
        "Maintain {{$key}} {{attendance}}",
        {
          key: "${anyValueToInt(value)}%",
          "attendance": languageProvider.getMessage("attendance", "attendance")
        },
      );
    } else if (key == AppStrings.requiredRating) {
      return languageProvider.getFormattedMessage2("upgrade_tier_rating",
          "Maintain a rating of {{$key}}", {key: "$value+"});
    } else if (key == AppStrings.requiredAttendanceDays) {
      return languageProvider.getFormattedMessage2(
          "upgrade_tier_attendance_days", "Minimum {{$key}} {{days}} present", {
        key: "$value",
        "days": languageProvider.getMessage("days", "days"),
      });
    } else {
      return '';
    }
  }
}

class _ChecklistItem extends StatelessWidget {
  final bool isAchieved;
  final String? text;

  const _ChecklistItem({required this.isAchieved, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text == null || text?.isEmpty == true) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        isAchieved
            ? const _CheckIcon(color: Color(0xFF52BD94))
            : Icon(
                Icons.access_time,
                size: 16.r,
                color: const Color(0xFFFFB020),
              ),
        SizedBox(width: 9.2.w),
        Expanded(
            child: CustomTextHighlighter(
          text: text ?? '',
          textStyle: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w400,
                height: 23 / 14,
                color: const Color(0xFF1B223C),
              ),
          customHighlighter: (text) => Text(
            text,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B223C),
                ),
          ),
        )),
      ],
    );
  }
}

class _CheckIcon extends StatelessWidget {
  final Color color;

  const _CheckIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16.w,
      height: 16.h,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.check,
          size: 12.w,
          color: const Color(0xFFF5FBF8),
        ),
      ),
    );
  }
}

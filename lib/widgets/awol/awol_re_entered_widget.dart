import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/awol/awol_models.dart';
import '../../providers/language_provider.dart';
import '../../services/remote_config/remote_config_assets.dart';
import '../../utils/awol_strings.dart';
import '../../utils/colors.dart';
import 'awol_view_helper.dart';

/// Re-entered state widget — shown when expert returns to the hotspot.
///
/// [isDialog] = true: modal card (20dp radius). No home card mode per spec.
class AwolReEnteredWidget extends StatelessWidget {
  final AwolData data;
  final LanguageProvider languageProvider;
  final bool isDialog;
  final VoidCallback? onUnderstood;

  const AwolReEnteredWidget({
    super.key,
    required this.data,
    required this.languageProvider,
    this.isDialog = true,
    this.onUnderstood,
  });

  AwolViewHelper get _helper => AwolViewHelper(data: data, lp: languageProvider);

  @override
  Widget build(BuildContext context) {
    final radius = isDialog ? 20.r : 8.r;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.61],
          colors: [AppColors.awolReEnteredGradientStart, AppColors.n0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapSection(context, radius),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 14.h),
                    Text(
                      _helper.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.g40,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      _helper.warning,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16.sp,
                        color: AppColors.n80,
                        height: 20 / 16,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    _buildConsequencesList(context),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
            child: SizedBox(
              width: double.infinity,
              height: 47.h,
              child: OutlinedButton(
                onPressed: onUnderstood,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.n90),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  languageProvider.getMessage(
                      AwolStrings.understoodKey, AwolStrings.understoodDefault),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 18 / 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsequencesList(BuildContext context) {
    final items = data.consequences;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildConsequenceItem(context, items[i]),
          if (i < items.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Divider(height: 1.h, color: AppColors.n30),
            ),
        ],
      ],
    );
  }

  Widget _buildConsequenceItem(BuildContext context, AwolConsequence consequence) {
    return Row(
      children: [
        Container(
          width: 52.r,
          height: 52.r,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26.r),
            color: AppColors.n20,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26.r),
            child: consequence.iconUrl != null &&
                    consequence.iconUrl!.isNotEmpty
                ? Image.network(
                    consequence.iconUrl!,
                    width: 52.r,
                    height: 52.r,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.warning_amber_rounded,
                          size: 28.r, color: AppColors.r40),
                    ),
                  )
                : Center(
                    child: Icon(Icons.warning_amber_rounded,
                        size: 28.r, color: AppColors.r40),
                  ),
          ),
        ),
        SizedBox(width: 12.w),
        if (consequence.text != null)
          Expanded(
            child: Text(
              languageProvider.getFormattedMessage(
                  consequence.text!.key, consequence.text!.defaultText, consequence.text!.params),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.awolDarkText,
                height: 18 / 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapSection(BuildContext context, double radius) {
    return SizedBox(
      height: 203.h,
      width: double.infinity,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(radius)),
            child: Image.network(
              data.imageUrl ?? RemoteConfigAssets.awolBackInHotspot,
              width: double.infinity,
              height: 203.h,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: double.infinity,
                height: 203.h,
                color: AppColors.awolReEnteredGradientStart
                    .withValues(alpha: 0.5),
                child: Center(
                  child: Icon(Icons.map_outlined,
                      size: 80.r, color: AppColors.g20),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16.h,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.n0,
                  borderRadius: BorderRadius.circular(40.r),
                ),
                child: Text(
                  _helper.badge,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.g40,
                    letterSpacing: 0.5,
                    height: 16 / 12,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 42.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.awolReEnteredGradientStart
                        .withValues(alpha: 0),
                    AppColors.awolReEnteredGradientStart,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

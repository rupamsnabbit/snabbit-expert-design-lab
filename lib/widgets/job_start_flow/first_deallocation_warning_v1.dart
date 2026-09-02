import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_text_highlighter.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Static UI widget showing the first deallocation warning card
/// exactly as per the Figma design.
class FirstDeallocationWarningV1 extends StatelessWidget {
  final LanguageProvider languageProvider;
  final DeallocationWarningType warningType;

  const FirstDeallocationWarningV1({
    super.key,
    required this.languageProvider,
    required this.warningType,
  });

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 22.h,
          ),
          _Header( languageProvider: languageProvider,),
          SizedBox(height: 28.h),
          _WarningCard(
            languageProvider: languageProvider,
            warningType: warningType,
          ),
        ],
      ),
    );
  }

}

class _Header extends StatelessWidget {
  final LanguageProvider languageProvider;
  const _Header({required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RemoteImageHandler(
          imageUrl: RemoteConfigAssets.deallocationFirstWarningHeader,
          fit: BoxFit.contain,
          height: 48.h,
        ),
        SizedBox(height: 16.h),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            languageProvider.getMessage(
                "first_deallocation_warning_title", 'Want to deny this job?'),
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}


class _WarningCard extends StatelessWidget {
  final LanguageProvider languageProvider;
  final DeallocationWarningType warningType;
  const _WarningCard({required this.languageProvider, required this.warningType,});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        width: 353.w,
        decoration: BoxDecoration(
          color: AppColors.n0,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            width: 1.2.r,
            color: const Color(0xFFF2F3F7),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopWarningRow(
              languageProvider: languageProvider,
              warningType: warningType,
            ),
            const Divider(
              color: Color(0xFFF9F9FB),
              height: 0,
            ),
            if (warningType != DeallocationWarningType.none)
              _BottomWarningRow(
                languageProvider: languageProvider,
                warningType: warningType,
              ),
          ],
        ),
      ),
    );
  }
}



class _SubtitleText extends StatelessWidget {
  final String text;
  const _SubtitleText({required this.text});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return  Flexible(
      child: LayoutBuilder(
          builder: (context,constraints) {
            return FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: constraints.maxWidth,
                child: CustomTextHighlighter(
                  text: text,
                  customHighlighter: (text) => Text(
                    text,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  textStyle: textTheme.bodyLarge,
                  textAlign: TextAlign.left,
                ),
              ),
            );
          }
      ),
    );
  }
}

class _TopWarningRow extends StatelessWidget {
  final LanguageProvider languageProvider;
  final DeallocationWarningType warningType;
  const _TopWarningRow({required this.languageProvider, required this.warningType,});


  @override
  Widget build(BuildContext context) {
      final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: 10.h,
        horizontal: 16.w,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.n0,
            Color(0xFFFFEBEB),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RemoteImageHandler(
            imageUrl: RemoteConfigAssets.deallocationFirstWarningItem1,
            fit: BoxFit.contain,
            width: 60.67.r,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  child: Text(
                    languageProvider.getMessage('warning_uppercase', "WARNING"),
                    style: textTheme.displaySmall?.copyWith(
                      color: AppColors.r40,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                SizedBox(height: 3.h),
                _SubtitleText(text: languageProvider.getMessage(
                    'first_deallocation_warning_item_1',
                    'Denying jobs is {{Not Allowed.}}'),),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class _BottomWarningRow extends StatelessWidget {
  final LanguageProvider languageProvider;
  final DeallocationWarningType warningType;
  const _BottomWarningRow({required this.languageProvider, required this.warningType,});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 10.h,
        horizontal: 16.w,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RemoteImageHandler(
            imageUrl: RemoteConfigAssets.deallocationFirstWarningItem2,
            fit: BoxFit.contain,
            width: 60.67.r,
          ),
          SizedBox(width: 12.w),
          _SubtitleText(text: warningType == DeallocationWarningType.goodShift
              ? languageProvider.getMessage(
              'first_deallocation_warning_item_2_good_shift',
              'You will {{lose Good Shift}} if you deny any more jobs')
              : languageProvider.getMessage(
              'first_deallocation_warning_item_2_ming',
              'You will {{lose MinG}} if you deny any more jobs'),),
        ],
      ),
    );
  }
}

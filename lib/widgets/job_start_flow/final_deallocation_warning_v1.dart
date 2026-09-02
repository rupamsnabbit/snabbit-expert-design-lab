import 'package:comm_stream/ui/widgets/remote_image_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_text_highlighter.dart';

import '../../utils/enums.dart';

class FinalDeallocationWarningV1 extends StatelessWidget {
  final LanguageProvider languageProvider;
  final DeallocationWarningType warningType;

  const FinalDeallocationWarningV1({
    super.key,
    required this.languageProvider,
    required this.warningType,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          RemoteImageHandler(
            imageUrl: RemoteConfigAssets.jobRejectionWarningImage,
            fit: BoxFit.contain,
            width: 100.r,
          ),
          SizedBox(height: 16.h),
          Flexible(
            child: LayoutBuilder(
              builder: (context,constraints) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: CustomTextHighlighter(
                      text: warningType == DeallocationWarningType.goodShift
                          ? languageProvider.getMessage(
                              'final_deallocation_warning_item_1_good_shift',
                              'You will {{Lose Good Shift}}\nif you Do Not Accept',
                            )
                          : languageProvider.getMessage(
                              'final_deallocation_warning_item_2_ming',
                              'You will {{Lose MinG}}\nif you Do Not Accept',
                            ),
                      customHighlighter: (text) => Text(
                        text,
                        style: textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: (26 / 22).sp,
                          color: AppColors.r40,
                        ),
                      ),
                      textStyle: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: (26 / 22).sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}

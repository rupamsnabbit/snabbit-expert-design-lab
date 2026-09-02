import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/shift_insight.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class ShiftInsightItem extends StatefulWidget {
  const ShiftInsightItem({
    super.key,
    required this.shiftInsight,
    required this.showDescription,
  });

  final ShiftInsight shiftInsight;
  final bool showDescription;

  @override
  State<ShiftInsightItem> createState() => _ShiftInsightItemState();
}

class _ShiftInsightItemState extends State<ShiftInsightItem> {
  bool init = true;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            RemoteImageHandler(
              imageUrl: widget.shiftInsight.imageUrl.cdn,
              height: 56.h,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionalTranslation(
                translation: const Offset(0, 0.5),
                child: RemoteImageHandler(
                  imageUrl: widget.shiftInsight.statusImageUrl.cdn,
                  height: 16.h,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Flexible(
          child: CustomTextNS(
            widget.shiftInsight.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.showDescription && widget.shiftInsight.subTitle != null) ...[
          SizedBox(height: 11.h),
          Flexible(
            child: CustomTextNS(
              widget.shiftInsight.subTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/early_payouts_model.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

class EarlyPayoutBenefitItem extends StatefulWidget {
  const EarlyPayoutBenefitItem({super.key, required this.benefit});

  final EarlyPayoutBenefit benefit;

  @override
  State<EarlyPayoutBenefitItem> createState() => _EarlyPayoutBenefitItemState();
}

class _EarlyPayoutBenefitItemState extends State<EarlyPayoutBenefitItem> {
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
    return Container(
      height: 100.h,
      width: 109.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          children: [
            Positioned.fill(
                child: RemoteImageHandler(
              imageUrl: widget.benefit.backgroundImage?.cdn ?? '',
              fit: BoxFit.cover,
            )),
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 8.h,
              child: Text(
                languageProvider.getMessage(
                  widget.benefit.title ?? '',
                  widget.benefit.title ?? '',
                ),
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.n80,
                    height: 14 / 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

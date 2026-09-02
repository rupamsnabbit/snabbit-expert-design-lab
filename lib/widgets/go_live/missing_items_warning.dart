import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/inventory_item.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';


class MissingItemsWarning extends StatefulWidget {
  final List<InventoryItem> missingItems;
  final VoidCallback onConfirm;
  final VoidCallback onGoBack;

  const MissingItemsWarning({
    Key? key,
    required this.missingItems,
    required this.onConfirm,
    required this.onGoBack,
  }) : super(key: key);

  @override
  State<MissingItemsWarning> createState() => _MissingItemsWarningState();
}

class _MissingItemsWarningState extends State<MissingItemsWarning> {
  bool outOfStock = false;
  late LanguageProvider languageProvider;
  bool init = true;

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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D1D1),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),

          // Warning icon
          SizedBox(
            height: 85.h,
            child: Image.asset(AssetConstants.fpWarningPng),
          ),

          SizedBox(height: 16.h),

          // Title + Items
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                languageProvider.getMessage('items_missing','Items missing'),
                style: textTheme.headlineMedium?.copyWith(
                  letterSpacing: -0.24,
                ),
              ),
              SizedBox(height: 12.h),
              for (final item in widget.missingItems)
                Text(
                  '${item.name ?? ''} x ${item.quantity ?? 0}',
                  style: textTheme.headlineMedium?.copyWith(
                    fontSize: 19.sp,
                    color: AppColors.n70,
                    letterSpacing: -0.24,
                  ),
                ),
            ],
          ),

          SizedBox(height: 24.h),

          // Checkbox
          Row(
            children: [
              Checkbox(
                value: outOfStock,
                activeColor: AppColors.brand,
                onChanged: (val) {
                  setState(() {
                    outOfStock = val ?? false;
                  });
                },
              ),
              Text(
                languageProvider.getMessage('items_out_of_stock','Items out of stock'),
                style:  textTheme.labelLarge?.copyWith(
                  fontSize: 16.sp,
                  letterSpacing: -0.24,
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.brand),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: widget.onGoBack,
                  child: Text(
                    languageProvider.getMessage('go_back','Go back'),
                    style:  textTheme.labelLarge?.copyWith(
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed:outOfStock? widget.onConfirm:null,
                  child: Text(
                    languageProvider.getMessage('confirm','Confirm'),
                    style:  textTheme.labelLarge?.copyWith(
                      color:outOfStock? AppColors.n0:AppColors.n60,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}


Future<bool> showMissingItemsWarning(BuildContext context,List<InventoryItem> missingItems,) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: MissingItemsWarning(
        missingItems:missingItems,
        onGoBack: () => Navigator.of(context).pop(false),
        onConfirm: () {
          // Handle confirm action
          Navigator.of(context).pop(true);
        },
      ),
    ),
  ).then((value) => value ?? false,);
}

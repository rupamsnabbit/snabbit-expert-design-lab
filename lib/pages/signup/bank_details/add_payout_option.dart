import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/widgets/circular_checkbox.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class AddPayoutOption extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool isSelected;

  const AddPayoutOption({
    super.key,
    required this.label,
    this.imageUrl,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          // Todo: Color missing in AppColors
          color: const Color(0xFFD8DAE5),
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  RemoteImageHandler(
                    imageUrl: imageUrl ?? '',
                    width: 24.r,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  )
                ],
              ),
            ),
            SizedBox(width: 8.w),
            CircularCheckbox(value: isSelected),
          ],
        ),
      ),
    );
  }
}

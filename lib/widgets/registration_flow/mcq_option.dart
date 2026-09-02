import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class McqOption extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  final bool? isEnabled;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? textColor;
  final Color? selectedTextColor;
  final String? selectedIcon;

  const McqOption({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
    this.isEnabled,
    this.selectedColor,
    this.unselectedColor,
    this.textColor,
    this.selectedTextColor,
    this.selectedIcon,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isSelected
        ? (selectedColor ?? AppColors.brand)
        : (unselectedColor ?? AppColors.n40);
    final double borderWidth = isSelected ? 2.0 : 1.0;

    return GestureDetector(
      onTap: (isEnabled ?? true) ? onTap : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 20.w)
            .subtract(EdgeInsets.all(isSelected ? 0.5 : 0)),
        decoration: BoxDecoration(
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: isSelected ? selectedTextColor : textColor),
            ),
            _buildSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelector() {
    final Color borderColor = isSelected ? AppColors.brand : AppColors.n40;
    final double borderWidth = isSelected ? 0.0 : 2.0;
    return Container(
      width: 24.r,
      height: 24.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.brand : Colors.transparent,
        border: selectedIcon != null
            ? null
            : Border.all(
                color: borderColor,
                width: borderWidth,
              ),
      ),
      child: isSelected
          ? selectedIcon != null
              ? RemoteImageHandler(
                  imageUrl: selectedIcon?.cdn ?? '',
                  width: 14.r,
                )
              : Icon(
                  Icons.check,
                  color: AppColors.n0,
                  size: 14.r,
                )
          : null,
    );
  }
}

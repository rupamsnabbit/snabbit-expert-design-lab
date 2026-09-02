import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

class StatusChipData {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const StatusChipData({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });
}

class DropDownList<T> extends StatefulWidget {
  final List<T> items;
  final String label;
  final T? initialSelection;
  final void Function(T?)? onSelectionChanged;
  final String Function(T) itemNameBuilder;
  final EdgeInsetsGeometry? padding;
  final bool showStatusChips;

  const DropDownList({
    super.key,
    required this.items,
    required this.label,
    this.initialSelection,
    this.onSelectionChanged,
    required this.itemNameBuilder,
    this.padding,
    this.showStatusChips = false,
  });

  @override
  State<DropDownList<T>> createState() => _DropDownListState<T>();
}

class _DropDownListState<T> extends State<DropDownList<T>> {
  late T? selectedItem;

  @override
  void initState() {
    super.initState();
    selectedItem = widget.initialSelection;
  }

  Widget _buildItemWithStatusChip(
      String itemName, int index, BuildContext context) {
    final statusData = _getStatusChipData(index, context);

    return Row(
      children: [
        Expanded(
          child: Text(
            itemName,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: statusData.backgroundColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            statusData.text,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: statusData.textColor,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  StatusChipData _getStatusChipData(int index, BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    switch (index) {
      case 0:
        return StatusChipData(
          text:
              '1 - ${languageProvider.getMessage("go_live_most_recommended", "Most Recommended")}',
          backgroundColor: AppColors.g10,
          textColor: AppColors.g50,
        );
      case 1:
        return StatusChipData(
          text:
              '2 - ${languageProvider.getMessage("go_live_recommended_2nd", "Recommended")}',
          backgroundColor: AppColors.g10,
          textColor: AppColors.g50,
        );
      case 2:
        return StatusChipData(
          text:
              '3 - ${languageProvider.getMessage("go_live_recommended_3rd", "Recommended")}',
          backgroundColor: AppColors.g10,
          textColor: AppColors.g50,
        );
      default:
        return const StatusChipData(
          text: '',
          backgroundColor: Colors.transparent,
          textColor: Colors.black,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (widget.items.isEmpty) {
        return const SizedBox.shrink();
      }
      final textTheme = Theme.of(context).textTheme;
      return Padding(
        padding: widget.padding ?? EdgeInsets.symmetric(horizontal: 16.w),
        child: SizedBox(
          // height: 32.h,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                  height: 14 / 16, // line height
                  color: const Color(0xFF1D2129),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Container(
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: AppColors.n0,
                    border: Border.all(
                      color: const Color(0xFFD8DAE5),
                      width: 0.91.w,
                    ),
                    borderRadius: BorderRadius.circular(19.11.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 14.57.w),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<T>(
                      value: selectedItem,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18.21,
                        color: AppColors.n80,
                      ),
                      dropdownColor: AppColors.n0,
                      style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 12.sp,
                          height: 18 / 12,
                          letterSpacing: -0.218572,
                          color: AppColors.n90,
                          overflow: TextOverflow.ellipsis),
                      items: widget.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;

                        return DropdownMenuItem(
                          value: item,
                          child: widget.showStatusChips && index < 3
                              ? _buildItemWithStatusChip(
                                  widget.itemNameBuilder(item),
                                  index,
                                  context,
                                )
                              : Text(widget.itemNameBuilder(item)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (selectedItem != value) {
                          setState(() => selectedItem = value);
                        }
                        widget.onSelectionChanged?.call(selectedItem);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // in case duplicate items are present in list exception will be thrown
      return const SizedBox.shrink();
    }
  }
}

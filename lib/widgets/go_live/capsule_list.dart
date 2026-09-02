import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'capsule_item.dart'; // Assuming CapsuleItem is already created

class CapsuleList<T> extends StatefulWidget {
  final String label;
  final String? description;
  final List<T> items;
  final String Function(T) titleBuilder;
  final String? Function(T)? subtitleBuilder;
  final void Function(T?)? onSelectionChanged;
  final Color selectedItemBackgroundColor;
  final Color selectedItemTextColor;
  final Color unselectedItemTextColor;
  final Color unselectedItemBorderColor;
  final T? initialSelectedItem;
  final bool isCircle;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? itemPadding;
  final TextStyle? labelStyle;
  final TextStyle? descriptionStyle;
  final double? itemSpacing;

  const CapsuleList({
    Key? key,
    required this.label,
    required this.items,
    required this.titleBuilder,
    this.subtitleBuilder,
    this.onSelectionChanged,
    this.selectedItemBackgroundColor = AppColors.p50,
    this.selectedItemTextColor = AppColors.n0,
    this.unselectedItemTextColor = const Color(0xFF525871),
    this.unselectedItemBorderColor = const Color(0xFFD8DAE5),
    this.initialSelectedItem,
    this.isCircle = false,
    this.padding,
    this.itemPadding,
    this.labelStyle,
    this.itemSpacing,
    this.description,
    this.descriptionStyle,
  }) : super(key: key);

  @override
  State<CapsuleList<T>> createState() => _CapsuleListState<T>();
}

class _CapsuleListState<T> extends State<CapsuleList<T>> {
  T? _selectedItem;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialSelectedItem;
  }

  void _selectItem(T item) {
    if(item == _selectedItem){
      _selectedItem = null; // Deselect if the same item is clicked
    }else {
      _selectedItem = item;
    }
    setState(() {
    });
    widget.onSelectionChanged?.call(_selectedItem);
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (widget.items.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: widget.padding ?? EdgeInsets.symmetric(horizontal: 16.w),
        child: SizedBox(
          width: 1.sw,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 16.sp,
                      color: const Color(0xFF1D2129),
                      letterSpacing: -0.24,
                    ).merge(widget.labelStyle),
                  ),
                ),
              ),
              if(widget.description != null)
                ...[
                  SizedBox(height: 4.h),
                  Flexible(
                    child: FittedBox(
                      child: Text(
                        widget.description ?? '',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.n80,
                          letterSpacing: -0.24,
                        ).merge(widget.descriptionStyle),
                      ),
                    ),
                  ),
                ],
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.items.map((item) {
                    final isSelected = item == _selectedItem;
                    return Padding(
                      padding: EdgeInsets.only(right: widget.itemSpacing ??  8),
                      child: GestureDetector(
                        onTap: () => _selectItem(item),
                        child: CapsuleItem(
                          title: widget.titleBuilder(item),
                          subtitle: widget.subtitleBuilder?.call(item),
                          backgroundColor: isSelected ? widget.selectedItemBackgroundColor : Colors.transparent,
                          textColor: isSelected ? widget.selectedItemTextColor : widget.unselectedItemTextColor,
                          borderColor: isSelected ? widget.selectedItemBackgroundColor : widget.unselectedItemBorderColor,
                          isCircle: widget.isCircle,
                          padding: widget.itemPadding,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // Handle any errors that might occur during the build process
      return const SizedBox.shrink();
    }
  }
}

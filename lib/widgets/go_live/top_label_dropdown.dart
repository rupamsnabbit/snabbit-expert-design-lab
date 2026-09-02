import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TopLabelDropDown<T> extends StatefulWidget {
  final List<T> items;
  final String label;
  final T? initialSelection;
  final void Function(T?)? onSelectionChanged;
  final String Function(T) itemNameBuilder;

  const TopLabelDropDown({
    super.key,
    required this.items,
    required this.label,
    this.initialSelection,
    this.onSelectionChanged,
    required this.itemNameBuilder,
  });

  @override
  State<TopLabelDropDown<T>> createState() => _TopLabelDropDownState<T>();
}

class _TopLabelDropDownState<T> extends State<TopLabelDropDown<T>> {
  late T? selectedItem;

  @override
  void initState() {
    super.initState();
    selectedItem = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
   try{
     if (widget.items.isEmpty) {
       return const SizedBox.shrink();
     }

     final textTheme = Theme.of(context).textTheme;

     return Container(
       width: 161.w,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         mainAxisSize: MainAxisSize.min,
         children: [
           // Label
           Text(
             widget.label,
             style: textTheme.labelLarge?.copyWith(
               fontSize: 16.sp,
               fontWeight: FontWeight.w600,
               height: 14 / 16,
               color: const Color(0xFF1D2129),
             ),
           ),
           SizedBox(height: 4.h),
           // Dropdown container
           Container(
             width: 161.w,
             height: 45.h,
             padding:
             EdgeInsets.symmetric(horizontal: 14.57.w, vertical: 13.66.h),
             decoration: BoxDecoration(
               color: AppColors.n0,
               border: Border.all(
                 color: const Color(0xFFD8DAE5),
                 width: 0.91.w,
               ),
               borderRadius: BorderRadius.circular(9.11.r),
             ),
             child: DropdownButtonHideUnderline(
               child: DropdownButton<T>(
                 value: selectedItem,
                 isExpanded: true,
                 icon: Container(
                   width: 18.21.w,
                   height: 18.21.h,
                   child: const Icon(
                     Icons.keyboard_arrow_down_rounded,
                     size: 18.21,
                     color: AppColors.n80,
                   ),
                 ),
                 dropdownColor: AppColors.n0,
                 alignment: Alignment.bottomCenter,
                 style: textTheme.bodyMedium?.copyWith(
                   fontSize: 13.66.sp,
                   fontWeight: FontWeight.w500,
                   height: 18 / 13.66,
                   letterSpacing: -0.218572,
                   color: AppColors.n90,
                     overflow: TextOverflow.ellipsis
                 ),
                 items: widget.items
                     .map((item) => DropdownMenuItem(
                   value: item,
                   child: Text(
                     widget.itemNameBuilder(item),
                     overflow: TextOverflow.ellipsis,
                   ),
                 ))
                     .toList(),
                 onChanged: (value) {
                   if (selectedItem != value) {
                     setState(() => selectedItem = value);
                   }
                   widget.onSelectionChanged?.call(selectedItem);
                 },
                 hint: Text(
                   'Select',
                   style: textTheme.bodyMedium?.copyWith(
                     fontSize: 13.66.sp,
                     fontWeight: FontWeight.w500,
                     color: const Color(0xFFD8DAE5),
                   ),
                 ),
               ),
             ),
           ),
         ],
       ),
     );
   }catch(e) {
     //in case of duplicate items in list exception will be thrown
     return const SizedBox.shrink();
   }
  }
}

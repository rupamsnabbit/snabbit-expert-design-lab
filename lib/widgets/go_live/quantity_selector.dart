import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/main.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class QuantitySelector extends StatefulWidget {
  final String label;
  final int initialValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const QuantitySelector({
    Key? key,
    required this.label,
    this.initialValue = 0,
    this.maxValue = 99,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  late int quantity;

  @override
  void initState() {
    super.initState();
    quantity = widget.initialValue;
  }

  void _increment() {
    if (quantity < widget.maxValue) {
      setState(() => quantity++);
      widget.onChanged(quantity);
    } else {
      showSnackbar(
        context,
        "Only ${widget.maxValue} ${widget.maxValue == 1 ? 'item' : 'items'} can be selected",
      );
    }
  }

  void _decrement() {
    if (quantity > 0) {
      setState(() => quantity--);
      widget.onChanged(quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.label,
          style: textTheme.displaySmall?.copyWith(
            color: AppColors.n90,
          ),
        ),
        Container(
          height: 42.h,
          width: 140.w,
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.n40,
              width: 0.65,
            ),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconButton(Icons.remove, _decrement, isAdd: false),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Text(
                  '$quantity',
                  style: textTheme.displaySmall?.copyWith(
                    color: Color(0xFF1D2129),
                  ),
                ),
              ),
              _buildIconButton(Icons.add, _increment),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed,
      {bool isAdd = true}) {
    return SizedBox(
      width: 24.w,
      height: 24.h,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(99),
        child: Icon(
          icon,
          size: 20.r,
          color: isAdd ? Color(0xFF1D2129) : AppColors.n60,
        ),
      ),
    );
  }
}

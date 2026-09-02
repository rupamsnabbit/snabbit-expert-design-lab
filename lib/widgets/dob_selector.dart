import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class DobSelector extends StatelessWidget {
  final void Function()? onTap;
  final TextEditingController dobDay;
  final TextEditingController dobMonth;
  final TextEditingController dobYear;
  final bool enabled;

  const DobSelector({
    super.key,
    required this.onTap,
    required this.dobDay,
    required this.dobMonth,
    required this.dobYear,
    this.enabled=true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              height: 48.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.n40),
                color: AppColors.n0,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.r),
                child: Center(
                  child: Text(
                    dobDay.text.isEmpty ? 'Day' : dobDay.text,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: dobDay.text.isNotEmpty && enabled
                          ? AppColors.n90
                          : AppColors.n50,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              height: 48.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.n40),
                color: AppColors.n0,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.r),
                child: Center(
                  child: Text(
                    dobMonth.text.isEmpty ? 'Month' : dobMonth.text,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: dobMonth.text.isNotEmpty && enabled
                          ? AppColors.n90
                          : AppColors.n50,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              height: 48.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.n40),
                color: AppColors.n0,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.r),
                child: Center(
                  child: Text(
                    dobYear.text.isEmpty ? 'Year' : dobYear.text,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: dobYear.text.isNotEmpty && enabled
                          ? AppColors.n90
                          : AppColors.n50,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

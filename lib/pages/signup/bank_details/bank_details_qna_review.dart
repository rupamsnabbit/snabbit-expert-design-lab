import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BankDetailsQnaReview extends StatelessWidget {
  final String? question;
  final String? answer;
  const BankDetailsQnaReview({
    super.key,
    this.question,
    this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question != null)
          Text(
            question!,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        SizedBox(height: 8.h),
        if (answer != null)
          Text(
          answer!,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

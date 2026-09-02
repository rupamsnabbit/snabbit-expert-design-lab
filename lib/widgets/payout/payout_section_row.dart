import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PayoutDetail {
  final Widget? heading;
  final Widget content;
  final Widget title;

  const PayoutDetail({
    this.heading,
    required this.content,
    required this.title,
  });
}

class PayoutSectionRow extends StatelessWidget {
  final List<PayoutDetail> children;

  const PayoutSectionRow({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First row - Headings with transparent divider
        Row(
          children: List.generate(children.length * 2 - 1, (index) {
            if (index.isEven) {
              final child = children[index ~/ 2];
              if (child.heading != null) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: child.heading!,
                  ),
                );
              }
            }
            return Container(
              margin: EdgeInsets.only(
                right: 32.5.w,
                left: 8.w,
              ),
              width: 1.5.w,
            ); // Width of divider + margins
          }),
        ),
        // Second row - Content with gradient divider
        IntrinsicHeight(
          child: Row(
            children: List.generate(children.length * 2 - 1, (index) {
              if (index.isEven) {
                final child = children[index ~/ 2];
                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      child.title,
                      SizedBox(height: 4.h),
                      child.content,
                    ],
                  ),
                );
              }
              return Container(
                alignment: Alignment.bottomRight,
                width: 1.5.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFA0A7AE).withOpacity(0),
                      const Color(0xFFA0A7AE).withOpacity(0.3),
                      const Color(0xFFA0A7AE).withOpacity(0.3),
                      const Color(0xFFA0A7AE).withOpacity(0),
                    ],
                    stops: const [0, 0.254, 0.72, 1],
                  ),
                ),
                margin: EdgeInsets.only(
                  right: 32.5.w,
                  left: 8.w,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

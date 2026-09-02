import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum ReferralStatusEnum {
  referred,
  joined,
}

class ReferralStatusWidget extends StatelessWidget {
  final ReferralStatusEnum status;
  final Widget child;

  const ReferralStatusWidget({
    super.key,
    this.status = ReferralStatusEnum.referred,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ReferralStatusEnum.joined) {
      return Stack(
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0xFF555350),
              BlendMode.modulate,
            ),
            child: child,
          ),
          Positioned.fill(
            child: Icon(
              Icons.check_rounded,
              color: const Color(0xff26A179),
              size: 24.sp,
            ),
          ),
        ],
      );
    }

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: child,
    );
  }
}

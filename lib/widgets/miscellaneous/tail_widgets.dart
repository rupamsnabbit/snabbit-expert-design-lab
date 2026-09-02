import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';

class TailWidgets {
  static get petAverse => Padding(
    padding: EdgeInsets.only(left: 4.w),
    child: Row(
      children: [
        SvgPicture.asset(AssetConstants.dog,),
        SvgPicture.asset(AssetConstants.cat,),
      ],
    ),
  );
}
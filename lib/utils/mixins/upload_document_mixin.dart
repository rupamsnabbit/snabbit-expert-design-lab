import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snabbit_runner/utils/colors.dart';

//TODO: CLEAN AND OPTIMIZE
mixin UploadDocumentsMixin{
  final ImagePicker picker = ImagePicker();

  Widget getVerifiedIndicator() {
    return Container(
      height: 14.r,
      width: 14.r,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.g40,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check,
        color: AppColors.n0,
        size: 7.sp,
      ),
    );
  }

  Widget getVerifyButton(VoidCallback onTap){
   return  GestureDetector(
      onTap: onTap,
      child: const Text(
        'Verify',
        style:
        TextStyle(color: AppColors.brand),
      ),
    );
  }
}
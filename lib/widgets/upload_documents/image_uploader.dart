import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/utils/colors.dart';

class ImageUploader extends StatelessWidget {
  const ImageUploader({
    super.key,
    this.localImage,
    this.storedImage,
    this.label,
    this.onDelete,
  });

  final String? localImage;
  final String? storedImage;
  final String? label;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 113.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.n40)),
      child: storedImage == null && localImage == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AssetConstants.uploadPic,
                  height: 40.h,
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      label ?? "Upload a pic",
                      textAlign: TextAlign.center,
                      // overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.n50),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              height: 80.h,
              width: 120.w,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(12.r),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: localImage != null
                            ? Image.file(
                                File(localImage!),
                                fit: BoxFit.cover,
                              )
                            : storedImage != null
                                ? Image.network(
                                    storedImage!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: getLoadingBuilder,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Text(
                                      "Image not found",
                                      textAlign: TextAlign.center,
                                    )),
                                  )
                                : null,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: SvgPicture.asset(
                        AssetConstants.cancelUploadPic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget getLoadingBuilder(
      BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress?.cumulativeBytesLoaded ==
        loadingProgress?.expectedTotalBytes) {
      return child; // Image is fully loaded
    }
    return Container(
      height: 80.h,
      width: 120.w,
      decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.n40,
          ),
          borderRadius: BorderRadius.circular(
            8.r,
          )),
      child: const CupertinoActivityIndicator(),
    );
  }
}

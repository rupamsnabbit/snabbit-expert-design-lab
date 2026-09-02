import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';

class BannerWithMedia extends StatelessWidget {
  final String? message;
  final String? foregroundImage;
  final String? backgroundImage;
  final bool foregroundImageOnLeft;
  final Color? backgroundColor;
  final BorderRadiusGeometry? borderRadius;
  final Widget? cta;
  final MainAxisAlignment? ctaAlignment;

  const BannerWithMedia({
    super.key,
    this.message,
    this.foregroundImage,
    this.backgroundImage,
    this.foregroundImageOnLeft = true,
    this.backgroundColor,
    this.borderRadius,
    this.cta,
    this.ctaAlignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(16.r),
        image: backgroundImage != null
            ? DecorationImage(
                image: AssetImage(backgroundImage!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w,vertical: 2.5.h,),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (foregroundImageOnLeft && foregroundImage != null)
            _ForegroundImage(key:key,foregroundImage: foregroundImage!),
            Flexible(
              child: _Message(
                key:key,
                message: message,
                cta: cta,
                ctaAlignment: ctaAlignment,
              ),
            ),
          if (!foregroundImageOnLeft && foregroundImage != null)
            _ForegroundImage(key:key,foregroundImage: foregroundImage!),
        ],
      ),
    );
  }
}

class _ForegroundImage extends StatelessWidget {
  final String foregroundImage;

  const _ForegroundImage({
    super.key,
    required this.foregroundImage,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Image.asset(
        foregroundImage,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.image_outlined),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String? message;
  final Widget? cta;
  final MainAxisAlignment? ctaAlignment;

  const _Message({
    super.key,
    this.message,
    this.cta,
    this.ctaAlignment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message ?? '',
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(color: const Color(0xFF1D2129)),
          ),
         if(cta!=null) Padding(
           padding: EdgeInsets.only(top: 10.h),
           child: Row(
              mainAxisAlignment: ctaAlignment ?? MainAxisAlignment.start,
              children: [
                Flexible(child: cta!)
              ],
            ),
         )
        ],
      ),
    );
  }
}

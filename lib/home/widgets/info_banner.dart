import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart'
    show RemoteImageHandler;

import '../models/info_banner.dart';

class InfoBanner extends StatelessWidget {
  final InfoBannerModel infoBannerModel;

  const InfoBanner({super.key, required this.infoBannerModel});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, languageProvider, _) {
      return Stack(
        children: [
          RemoteImageHandler(
            imageUrl: infoBannerModel.bgImage?.url?.cdn ?? "",
            width: double.infinity,
          ),
          Positioned.fill(
            child: Row(
              children: [
                RemoteImageHandler(
                  imageUrl: infoBannerModel.icon?.url?.cdn ?? "",
                  height: infoBannerModel.icon?.height,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 6.h),
                          child: Text(
                            languageProvider.getMessage(infoBannerModel.title ?? "",
                                infoBannerModel.title ?? ""),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(color: AppColors.n0),
                          ),
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(top: 6.h),
                          child: Text(
                            languageProvider.getMessage(
                                infoBannerModel.subtitle ?? "",
                                infoBannerModel.subtitle ?? ""),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Color(0xffFFC537),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
              ],
            ),
          ),
        ],
      );
    });
  }
}

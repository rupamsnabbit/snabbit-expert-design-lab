import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/referrals/models/leaderboard_models.dart';
import 'package:snabbit_runner/referrals/widgets/sunburst_rays_widget.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/golden_text_widget.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class ContestResultDialog extends StatelessWidget {
  final LeaderboardResponse? leaderboardData;
  final int userRank;

  const ContestResultDialog(
      {super.key, this.leaderboardData, required this.userRank});

  @override
  Widget build(BuildContext context) {
    final winningConfig = leaderboardData?.currentUser?.winningConfig;
    final PrizeType prizeType = winningConfig?.prizeType ?? PrizeType.noPrize;

    final bool didWin =
        prizeType == PrizeType.topPrize || prizeType == PrizeType.rankedPrize;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 0.05.sw),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: !didWin ? const Color(0xff545BC4) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Stack(alignment: Alignment.center, children: [
            if (didWin)
              Positioned.fill(
                child: SunburstRaysWidget(
                  primaryColor: const Color(0xff545BC4),
                  secondaryColor: Colors.white.withOpacity(0.08),
                  verticalPosition: 0.35,
                ),
              ),
            // Close button
            Positioned(
              top: 8.h,
              right: 8.w,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: SvgPicture.asset(
                  AssetConstants.cancelUploadPic,
                  height: 33.h,
                  width: 33.w,
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: didWin
                  ? _TopRankContent(
                      winningConfig: winningConfig ?? WinningConfig(),
                      userRank: userRank)
                  : _NoRankContent(
                      imageUrl: winningConfig?.prizeImage?.url.toString() ?? "",
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TopRankContent extends StatelessWidget {
  final WinningConfig? winningConfig;
  final int userRank;

  const _TopRankContent({required this.winningConfig, required this.userRank});

  bool get isTopRank => winningConfig?.prizeType == PrizeType.topPrize;

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 30.h),
        CustomTextNS(
          winningConfig?.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.n0,
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
              ),
        ),
        SizedBox(height: 18.h),
        RemoteImageHandler(
          imageUrl: winningConfig?.prizeImage?.url ?? "",
          height: 140.h,
          fit: BoxFit.fitHeight,
        ),
        SizedBox(height: 14.h),
        if (isTopRank) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Color(0xff612115),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                    ),
                children: [
                  TextSpan(text: userRank.toString()),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Text(
                      getDaySuffix(userRank).toUpperCase(),
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Color(0xff612115),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                    ),
                  ),
                  TextSpan(
                      text:
                          " ${languageProvider.getMessage('prize', 'PRIZE')}"),
                ],
              ),
            ),
          ),
        ] else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              // Let the badge define intrinsic size; add internal padding for bubble
              final badge =
                  _buildGenericRankBadge(languageProvider, context, userRank);

              return IntrinsicWidth(
                child: IntrinsicHeight(
                  child: CustomPaint(
                    painter: _NoRankBadgeBackgroundCustomPainter(),
                    child: badge,
                  ),
                ),
              );
            },
          ),
        ],
        SizedBox(height: 16.h),
        GoldenTextWidget.fromCustomText(
          textData: winningConfig?.winningText ?? {},
          fontSize: 40.sp,
        ),
        SizedBox(height: 20.h),
        CustomTextNS(
          winningConfig?.subTitle,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.n0,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
        ),
        SizedBox(height: 38.h),
      ],
    );
  }

  Widget _buildGenericRankBadge(
      LanguageProvider languageProvider, BuildContext context, int userRank) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 4.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            languageProvider.getMessage('your_rank', 'Your rank').toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.n0,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          userRank.toString(),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.n0,
                fontSize: 24.sp,
                fontWeight: FontWeight.w900,
              ),
        ),
        SizedBox(height: 4.h),
      ],
    );
  }
}

class _NoRankContent extends StatelessWidget {
  final String? imageUrl;

  const _NoRankContent({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 42.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            languageProvider.getMessage(
                'better_luck_next_time', 'Better Luck Next Time'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.n0,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        SizedBox(height: 4.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            languageProvider.getMessage('wait_for_next_contest',
                'Wait for the next contest announcement'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.n0,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        SizedBox(height: 24.h),
        SizedBox(
          height: 228.h,
          child: AspectRatio(
            aspectRatio: 228 / 241,
            child: imageUrl == null
                ? Image.asset(
                    AssetConstants.diwaliContest.noRankPng,
                    fit: BoxFit.fitHeight,
                  )
                : RemoteImageHandler(
                    imageUrl: imageUrl ?? "",
                    fit: BoxFit.cover,
                    errorWidget: Image.asset(
                      AssetConstants.diwaliContest.noRankPng,
                      fit: BoxFit.fitHeight,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}

class _NoRankBadgeBackgroundCustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scaling factors based on the original dimensions (140 x 52)
    final double scaleX = size.width / 140.0;
    final double scaleY = size.height / 52.0;

    // Helper function to scale coordinates
    double sx(double x) => x * scaleX;
    double sy(double y) => y * scaleY;

    Path path_0 = Path();
    path_0.moveTo(sx(0), sy(4));
    path_0.cubicTo(sx(0), sy(1.79086), sx(1.79086), sy(0), sx(4), sy(0));
    path_0.lineTo(sx(136), sy(0));
    path_0.cubicTo(sx(138.209), sy(0), sx(140), sy(1.79086), sx(140), sy(4));
    path_0.lineTo(sx(140), sy(26));
    path_0.lineTo(sx(111.128), sy(51.0228));
    path_0.cubicTo(
        sx(110.4), sy(51.653), sx(109.47), sy(52), sx(108.508), sy(52));
    path_0.lineTo(sx(31.4921), sy(52));
    path_0.cubicTo(
        sx(30.5298), sy(52), sx(29.5997), sy(51.653), sx(28.8724), sy(51.0228));
    path_0.lineTo(sx(0), sy(26));
    path_0.lineTo(sx(0), sy(4));
    path_0.close();

    Paint paint_0_fill = Paint()..style = PaintingStyle.fill;
    paint_0_fill.color = Color(0xff434CD0).withOpacity(1.0);
    canvas.drawPath(path_0, paint_0_fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

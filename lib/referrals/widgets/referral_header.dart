import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/referral_home.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/referrals/pages/diwali_contest_page.dart';
import 'package:snabbit_runner/referrals/widgets/bumper_reward_pool_widget.dart';
import 'package:snabbit_runner/referrals/widgets/friend_card.dart';
import 'package:snabbit_runner/referrals/widgets/referral_campaign_view.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/how_it_works_modal.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/underline_text_button.dart';
import 'package:video_player/video_player.dart';

import '../../providers/referral.dart';
import 'add_referral.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double? height;

  const GradientButton({
    super.key,
    required this.text,
    this.onTap,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: (height ?? 51).h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFD280), // top
              Color(0xFFCC6600), // bottom
            ],
          ),
        ),
        padding: const EdgeInsets.all(3),
        // border thickness
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFF4A60B),
                Color(0xFFFFCF33),
                Color(0xFFF4A60B),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class ReferNowButton extends StatelessWidget {
  final double? height;

  const ReferNowButton({
    super.key,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
      return GradientButton(
        height: height,
        text: languageProvider.getMessage(
          'refer_now',
          'Refer Now',
        ),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            constraints: BoxConstraints(
              maxHeight: 0.7.sh,
            ),
            builder: (_) {
              return AddReferral();
            },
          );
        },
      );
    });
  }
}

class ViewEarningsButton extends StatelessWidget {
  final double? height;
  final VoidCallback onTap;

  const ViewEarningsButton({
    super.key,
    this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
      return GradientButton(
        height: height,
        text: languageProvider.getMessage(
          'view_earnings',
          'View Earnings',
        ),
        onTap: onTap,
      );
    });
  }
}

class ViewLeaderboardButton extends StatelessWidget {
  final double? height;
  final ContestModel? contestData;

  const ViewLeaderboardButton({
    super.key,
    this.height,
    this.contestData,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
      return GradientButton(
        height: height,
        text: languageProvider.getMessage(
          'view_leaderboard',
          'View Leaderboard',
        ),
        onTap: () {
          Navigator.of(context).pushNamed(DiwaliContestPage.routeName);
        },
      );
    });
  }
}

class HowItWorksItem extends StatelessWidget {
  final int index;
  final Map<String, dynamic>? title;

  const HowItWorksItem({
    super.key,
    required this.index,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 35.r,
          height: 35.r,
          decoration: const BoxDecoration(
            color: Color(0xfff2edff),
            shape: BoxShape.circle,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              index.toString(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff676DC9),
                  ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: CustomText(
            textData: title,
          ),
        ),
      ],
    );
  }
}

class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoPlaying = false;

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        allowMuting: true,
        showControls: true,
        allowPlaybackSpeedChanging: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        additionalOptions: (context) => <OptionItem>[],
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.lightBlue,
        ),
      );

      setState(() {
        _isVideoPlaying = true;
      });
    } catch (e) {
      // Handle video initialization error
      debugPrint('Error initializing video: $e');
    }
  }

  void _onThumbnailTap() {
    _initializeVideo();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.sw,
      margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: _isVideoPlaying && _chewieController != null
          ? AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            )
          : GestureDetector(
              onTap: _onThumbnailTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: RemoteImageHandler(
                      imageUrl: widget.thumbnailUrl ?? "",
                      width: 1.sw,
                    ),
                  ),
                  Container(
                    width: 55.r,
                    height: 48.r,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class VideoPopupDialog extends StatefulWidget {
  final String videoUrl;

  const VideoPopupDialog({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoPopupDialog> createState() => _VideoPopupDialogState();
}

class _VideoPopupDialogState extends State<VideoPopupDialog> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoReady = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        allowMuting: true,
        showControls: true,
        allowPlaybackSpeedChanging: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        additionalOptions: (context) => <OptionItem>[],
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.lightBlue,
        ),
      );

      if (mounted) {
        setState(() {
          _isVideoReady = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20.w),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 0.9.sw,
          maxHeight: 0.7.sh,
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Stack(
          children: [
            if (_hasError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48.r,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Failed to load video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                      ),
                    ),
                  ],
                ),
              )
            else if (!_isVideoReady)
              Center(
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.w,
                ),
              )
            else if (_chewieController != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Chewie(controller: _chewieController!),
              ),
            Positioned(
              top: 8.h,
              right: 8.w,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20.r,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReferralHeaderView extends StatefulWidget {
  const ReferralHeaderView(
      {super.key, this.showViewMyReferrals = false, this.source});

  final bool showViewMyReferrals;
  final String? source;

  @override
  State<ReferralHeaderView> createState() => _ReferralHeaderViewState();
}

class _ReferralHeaderViewState extends State<ReferralHeaderView> {
  bool init = true;
  late ReferralDataProvider referralDataProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    if (referralDataProvider.referralData == null) return const SizedBox();
    return Container(
      width: 1.sw,
      decoration: BoxDecoration(
        color: const Color(0xff008E3E),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: ReferralHeaderBase(
        data: referralDataProvider.referralData!,
        showViewMyReferrals: widget.showViewMyReferrals,
        source: widget.source,
      ),
    );
  }
}

class ReferralHeaderBase extends StatefulWidget {
  final ReferralData data;
  final bool showViewMyReferrals;
  final String? source;

  const ReferralHeaderBase({
    super.key,
    required this.data,
    this.showViewMyReferrals = false,
    this.source,
  });

  @override
  State<ReferralHeaderBase> createState() => _ReferralHeaderBaseState();
}

class _ReferralHeaderBaseState extends State<ReferralHeaderBase> {
  bool init = true;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  bool get showLegacyReferrals =>
      (widget.data.campaignReferrals != null &&
          widget.data.campaignReferrals!.isNotEmpty) ||
      (widget.showViewMyReferrals == true);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RemoteImageHandler(imageUrl: widget.data.headerImage ?? ""),
        SizedBox(height: 14.h),
        ReferralShiftCampaigns(source: widget.source),
        Padding(
          padding: EdgeInsets.only(bottom: 20.h),
          child: UnderlineTextButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => HowItWorksModal(
                    videoUrl: widget.data.videoUrl,
                    thumbnailUrl: widget.data.thumbnailUrl,
                    howItWorksSteps: widget.data.howItWorksSteps,
                    title: languageProvider.getMessage(
                      'how_it_works',
                      "How it works",
                    )),
              );
            },
            text: languageProvider.getMessage(
              'view_all_rules',
              'View All Rules',
            ),
            textColor: AppColors.n0,
            underlineColor: AppColors.n0,
            textStyle: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.n0),
          ),
        ),
        if (showLegacyReferrals)
          Container(
            width: 1.sw,
            decoration: BoxDecoration(
              color: AppColors.n0,
              borderRadius: BorderRadius.circular(14.r),
            ),
            padding: EdgeInsets.all(18.r),
            margin: EdgeInsets.all(15.r),
            child: Column(
              children: [
                if (widget.data.campaignReferrals != null &&
                    widget.data.campaignReferrals!.isNotEmpty)
                  FriendCardList(
                    referrals: widget.data.campaignReferrals ?? [],
                  ),
                SizedBox(height: 18.h),
                if (widget.showViewMyReferrals == true) ...[
                  UnderlineTextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(ReferralsHome.routeName);
                    },
                    text: languageProvider.getMessage(
                      'view_my_referrals',
                      'View My Referrals',
                    ),
                  ),
                  SizedBox(height: 18.h),
                ],
              ],
            ),
          ),
        BumperRewardPoolWidget(
          contestData: widget.data.activeContest,
          isContestRunning:
              widget.data.activeContest?.status == ContestStatus.active,
        ),
      ],
    );
  }
}

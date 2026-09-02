import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:format/format.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/pages/payout/payout_home.dart';
import 'package:snabbit_runner/providers/contest_data_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/referral.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/referrals/models/contest_rank.dart';
import 'package:snabbit_runner/referrals/models/leaderboard_models.dart';
import 'package:snabbit_runner/referrals/widgets/contest_result_dialog.dart';
import 'package:snabbit_runner/referrals/widgets/referral_header.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/svg_strings.dart';
import 'package:snabbit_runner/widgets/app_error_widget.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/golden_text_widget.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class DiwaliContestPage extends StatefulWidget {
  static const String routeName = "/diwali-contest-page";

  const DiwaliContestPage({super.key});

  @override
  State<DiwaliContestPage> createState() => _DiwaliContestPageState();
}

class _DiwaliContestPageState extends State<DiwaliContestPage> {
  bool init = true;
  bool _hasShownDialog = false;
  late LanguageProvider languageProvider;
  late ContestDataProvider contestDataProvider;
  late UserProfileProvider userProfileProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      contestDataProvider =
          Provider.of<ContestDataProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      Future(() {
        contestDataProvider
            .fetchLeaderboardData(contestDataProvider.currentContest?.id ?? 0);
      });
    }
    super.didChangeDependencies();
  }

  void _checkAndShowDialog() {
    final currentContest = contestDataProvider.currentContest;
    final isContestRunning =
        contestDataProvider.isContestActive(currentContest?.id);
    final leaderboardData = contestDataProvider.currentLeaderboard;
    final isLoading = contestDataProvider.loading;

    // Show dialog if:
    // 1. Contest has ended (!isContestRunning)
    // 2. Data has been fetched (!isLoading && leaderboardData != null)
    // 3. Dialog hasn't been shown yet
    if (!isContestRunning &&
        !isLoading &&
        leaderboardData != null &&
        !_hasShownDialog &&
        mounted) {
      _hasShownDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCongratulationsDialog();
      });
    }
  }

  void _showCongratulationsDialog() {
    final currentUserRank = contestDataProvider.getCurrentUserRank() ?? 1;
    final leaderboardData = contestDataProvider.currentLeaderboard;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return ContestResultDialog(
          leaderboardData: leaderboardData,
          userRank: currentUserRank,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentContest = contestDataProvider.currentContest;
    final isContestRunning =
        contestDataProvider.isContestActive(currentContest?.id);
    final hasError = !contestDataProvider.loading &&
        (currentContest == null ||
            contestDataProvider.currentLeaderboard == null);

    // Check if we should show the congratulations dialog
    _checkAndShowDialog();

    return Scaffold(
      appBar: const CommonAppBar(),
      backgroundColor: const Color(0xffF5F6F8),
      body: Column(
        children: [
          Expanded(
            child: contestDataProvider.loading
                ? const Center(
                    child: CupertinoActivityIndicator(),
                  )
                : hasError
                    ? AppErrorWidget(
                        message: languageProvider.getMessage(
                            'generic_error', 'Something went wrong'),
                        onRetry: () {
                          contestDataProvider.fetchLeaderboardData(
                              contestDataProvider.currentContest?.id ?? 0);
                        },
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(20.r),
                          child: Column(
                            children: [
                              _ContestDetailsWidget(
                                isContestRunning: isContestRunning,
                                contestData: currentContest,
                                leaderboardData:
                                    contestDataProvider.currentLeaderboard,
                              ),
                              SizedBox(height: 20.h),
                              _LeaderboardWidget(
                                isContestRunning: isContestRunning,
                                contestData: currentContest,
                                leaderboardData:
                                    contestDataProvider.currentLeaderboard,
                                currentUserRank:
                                    contestDataProvider.getCurrentUserRank(),
                              ),
                              SizedBox(height: 100.h), // Space for bottom bar
                            ],
                          ),
                        ),
                      ),
          ),
          // using this approach because persistentFooterButtons didnt let us control the bottom bar padding
          contestDataProvider.loading
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    bottom: 20.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20.r),
                      topRight: Radius.circular(20.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: isContestRunning
                      ? _BottomBarContestRunning(
                          isContestRunning: true,
                          currentUserRank:
                              contestDataProvider.getCurrentUserRank(),
                          leaderboardData:
                              contestDataProvider.currentLeaderboard,
                        )
                      : _BottomBarContestEnded(
                          isContestRunning: false,
                          rank: contestDataProvider.getCurrentUserRank(),
                          leaderboardData:
                              contestDataProvider.currentLeaderboard,
                        ),
                ),
        ],
      ),
    );
  }
}

class HowToWinWidget extends StatelessWidget {
  final ContestModel? contestData;

  const HowToWinWidget({
    super.key,
    this.contestData,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                SvgStrings.diwaliContest.iconStar,
                height: 13.h,
                width: 13.w,
              ),
              SizedBox(width: 4.w),
              Text(
                languageProvider.getMessage('how_to_win', 'How to win'),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                      color: Colors.white,
                    ),
              ),
              SizedBox(width: 4.w),
              SvgPicture.asset(
                SvgStrings.diwaliContest.iconStar,
                height: 13.h,
                width: 13.w,
              ),
            ],
          ),
          ...(contestData?.rules ?? []).map((rule) => _ContestRuleRow(
                title: rule.title,
              )),
        ],
      ),
    );
  }
}

class _BottomBarContestRunning extends StatelessWidget {
  final bool isContestRunning;
  final int? currentUserRank;
  final LeaderboardResponse? leaderboardData;

  const _BottomBarContestRunning({
    required this.isContestRunning,
    this.currentUserRank,
    this.leaderboardData,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (currentUserRank != null)
          _LeaderboardListItem(
            rank: currentUserRank ?? 1,
            fromBottomBar: true,
            isContestRunning: isContestRunning,
            leaderboardData: leaderboardData,
            leaderboardEntry: leaderboardData?.currentUser,
          ),
        if (currentUserRank != null &&
            leaderboardData?.contestRankUpMessage != null)
          Container(
            height: 26.h,
            color: AppColors.y10,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: CustomTextNS(
                  leaderboardData?.contestRankUpMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 18 / 12,
                        letterSpacing: -0.24,
                        color: AppColors.n90,
                      ),
                ),
              ),
            ),
          ),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: const ReferNowButton(),
        ),
      ],
    );
  }
}

class _BottomBarContestEnded extends StatelessWidget {
  final bool isContestRunning;
  final int? rank;
  final LeaderboardResponse? leaderboardData;

  const _BottomBarContestEnded({
    required this.isContestRunning,
    required this.rank,
    this.leaderboardData,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (rank != null)
          _LeaderboardListItem(
            rank: rank ?? 0,
            fromBottomBar: true,
            isContestRunning: isContestRunning,
            leaderboardData: leaderboardData,
            leaderboardEntry: leaderboardData?.currentUser,
          ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
          ),
          child: ViewEarningsButton(onTap: () {
            Navigator.of(context).pop();
          }),
        ),
      ],
    );
  }
}

class _ContestDetailsWidget extends StatelessWidget {
  final bool isContestRunning;
  final ContestModel? contestData;
  final LeaderboardResponse? leaderboardData;

  const _ContestDetailsWidget({
    required this.isContestRunning,
    required this.contestData,
    required this.leaderboardData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF474D9E),
            Color(0xFF696FCC),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isContestRunning)
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: const Color(0xFF8D92D8).withOpacity(0.3),
              ),
              child: Column(
                children: [
                  CustomTextNS(
                    contestData?.displayTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.sp,
                          color: Colors.white,
                        ),
                  ),
                  SizedBox(height: 8.h),
                  GoldenTextWidget.fromCustomText(
                    textData: contestData?.displayPrize ?? {},
                    fontSize: 36.sp,
                  ),
                ],
              ),
            ),
          // SizedBox(height: 16.h),

          if (isContestRunning) ...[
            SizedBox(height: 16.h),
            _PrizeAnnouncementWidget(
              contestData: contestData,
            ),
            HowToWinWidget(
              contestData: contestData,
            ),
          ] else ...[
            _WinnersListWidget(
                leaderboardData: leaderboardData, contestData: contestData),
          ]
        ],
      ),
    );
  }
}

class _WinnersListWidget extends StatelessWidget {
  final LeaderboardResponse? leaderboardData;
  final ContestModel? contestData;

  const _WinnersListWidget({required this.leaderboardData, this.contestData});

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        color: const Color(0xFF666CBC),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFC4C8FE),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20.r),
                bottomRight: Radius.circular(20.r),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  languageProvider
                      .getMessage(
                          'contest_ended_date', 'Contest ended on {date}')
                      .format({
                    #date: contestData?.endDate != null
                        ? DateFormat('d MMMM yyyy')
                            .format(contestData!.endDate!)
                        : ''
                  }),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: const Color(0xFF1D2129),
                        fontWeight: FontWeight.w700,
                        fontSize: 10.sp,
                      ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          _WinnersListItemsWidget(leaderboardData: leaderboardData),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}

class _WinnersListItemsWidget extends StatelessWidget {
  final LeaderboardResponse? leaderboardData;

  const _WinnersListItemsWidget({required this.leaderboardData});

  @override
  Widget build(BuildContext context) {
    // Get first 3 winners sorted by rank order
    var topWinners = leaderboardData?.leaderboard?.take(3).toList() ?? [];

    // Reorder: rank 2 (index 1) -> left, rank 1 (index 0) -> middle, rank 3 (index 2) -> right
    var reorderedWinners = <dynamic>[];
    if (topWinners.isNotEmpty) {
      reorderedWinners.add(topWinners[0]);
    }
    if (topWinners.length >= 2) {
      reorderedWinners.insert(0, topWinners[1]);
    }
    if (topWinners.length >= 3) {
      reorderedWinners.add(topWinners[2]);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: reorderedWinners
            .map((winner) => Expanded(
                  child: _WinnerItemWidget(
                    name: winner.name ?? "",
                    referrals: winner.referralCount ?? 0,
                    rank:
                        ContestRankEnumExtension.rankToEnum(winner.order ?? 0),
                    imageUrl: winner.publicPic ?? "",
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _WinnerItemWidget extends StatelessWidget {
  final String name;
  final int referrals;
  final ContestRankEnum rank;
  final String imageUrl;

  const _WinnerItemWidget({
    required this.name,
    required this.referrals,
    required this.rank,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final contestProvider =
        Provider.of<ContestDataProvider>(context, listen: false);
    final contestUnit = contestProvider.currentContestUnit;

    return Column(
      children: [
        Column(
          children: [
            Container(
              width: rank == ContestRankEnum.first ? 70.w : 52.w,
              height: rank == ContestRankEnum.first ? 70.h : 52.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rank.textBorderColor, width: 2.w),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100.r),
                child: RemoteImageHandler(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: Image.network(
                    AssetConstants.avatarImagePlaceholder,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -12.h),
              child: LeaderBoardRankWidget(
                rank: ContestRankEnumExtension.enumToRank(rank),
              ),
            ),
          ],
        ),
        Text(
          name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15.sp,
                height: 18 / 15,
                letterSpacing: -0.24,
              ),
        ),
        SizedBox(height: 4.h),
        Text(
          referrals.toString(),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.n0,
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                height: 18 / 20,
                letterSpacing: -0.24,
              ),
        ),
        SizedBox(height: 2.h),
        CustomTextNS(
          contestUnit,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.n0,
                fontWeight: FontWeight.w500,
                fontSize: 10.sp,
                height: 12 / 10,
                letterSpacing: -0.24,
              ),
        ),
      ],
    );
  }
}

class _PrizeAnnouncementWidget extends StatefulWidget {
  final ContestModel? contestData;

  const _PrizeAnnouncementWidget({required this.contestData});

  @override
  State<_PrizeAnnouncementWidget> createState() =>
      _PrizeAnnouncementWidgetState();
}

class _PrizeAnnouncementWidgetState extends State<_PrizeAnnouncementWidget> {
  late Timer _timer;

  bool init = true;
  Duration _timeRemaining = Duration.zero;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTimeRemaining();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _updateTimeRemaining();
        });
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTimeRemaining() {
    final now = DateTime.now();
    final endTime = widget.contestData?.endDate;

    if (endTime != null && now.isBefore(endTime)) {
      setState(() {
        _timeRemaining = endTime.difference(now);
      });
    } else {
      setState(() {
        _timeRemaining = Duration.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return RemoteImageHandler(
                  imageUrl: widget.contestData?.bannerImage?.url ?? "",
                  width: constraints.maxWidth,
                  fit: BoxFit.fill,
                );
              },
            ),
            Positioned(
              top: 0,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 322.w - 48.w,
                  minWidth: 32.w,
                ),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFAB00B),
                      Color(0xFFFCD731),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20.r),
                    bottomRight: Radius.circular(20.r),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.black,
                      size: 16.w,
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          languageProvider
                              .getMessage('winners_declared_in_days',
                                  'Winners will be declared in : {days} days')
                              .format(
                                  {#days: _timeRemaining.inDays.toString()}),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.sp,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardListItem extends StatelessWidget {
  final bool fromBottomBar;
  final bool isFirst;
  final bool isLast;

  final int rank;
  final bool isContestRunning;
  final LeaderboardEntry? leaderboardEntry;
  final LeaderboardResponse? leaderboardData;

  const _LeaderboardListItem({
    this.fromBottomBar = false,
    this.isFirst = false,
    this.isLast = false,
    required this.rank,
    required this.isContestRunning,
    this.leaderboardEntry,
    this.leaderboardData,
  });

  @override
  Widget build(BuildContext context) {
    var rankEnum = ContestRankEnumExtension.rankToEnum(rank);
    if (rank == leaderboardData?.currentUser?.order) {
      rankEnum = ContestRankEnum.self;
    }

    final contestProvider =
        Provider.of<ContestDataProvider>(context, listen: false);
    final contestUnit = contestProvider.currentContestUnit;

    return Container(
      constraints: BoxConstraints(
        minHeight: fromBottomBar ? 54.h : 70.h,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft:
              isFirst || fromBottomBar ? Radius.circular(20.r) : Radius.zero,
          topRight:
              isFirst || fromBottomBar ? Radius.circular(20.r) : Radius.zero,
          bottomLeft:
              isLast && !fromBottomBar ? Radius.circular(20.r) : Radius.zero,
          bottomRight:
              isLast && !fromBottomBar ? Radius.circular(20.r) : Radius.zero,
        ),
        color: fromBottomBar ? AppColors.n0 : rankEnum.leaderboardBgColor,
      ),
      child: Row(
        children: [
          SizedBox(width: fromBottomBar ? 20.w : 12.5.w),
          LeaderBoardRankWidget(
            rank: rank,
          ),
          SizedBox(width: 12.w),
          Container(
            width: 36.w,
            height: 36.h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100.r),
              child: RemoteImageHandler(
                fit: BoxFit.cover,
                errorWidget: Image.network(
                  AssetConstants.avatarImagePlaceholder,
                  fit: BoxFit.cover,
                ),
                imageUrl: leaderboardEntry?.publicPic ??
                    AssetConstants.avatarImagePlaceholder,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              leaderboardEntry?.name ?? "Loading...",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF101840),
                  ),
            ),
          ),
          SizedBox(width: 8.w),
          if (!isContestRunning && fromBottomBar == true) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 0.4.sw,
                ),
                padding: EdgeInsets.only(bottom: 8.h, top: 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    leaderboardEntry?.winningConfig?.rankingDetails?.length ??
                        0,
                    (index) => _ReferralDescriptionRow(
                      rankingDetail: leaderboardEntry
                              ?.winningConfig?.rankingDetails?[index] ??
                          RankingDetail(),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            _ReferralDescriptionRow(
              rankingDetail: RankingDetail(
                  title: contestUnit,
                  value: leaderboardEntry?.referralCount?.toString() ?? "0"),
            ),

            // title: "Referrals",
            // description:
            // leaderboardEntry?.referralCount?.toString() ?? "0"),
          ],
          SizedBox(width: fromBottomBar ? 20.w : 32.w),
        ],
      ),
    );
  }
}

class LeaderBoardRankWidget extends StatelessWidget {
  const LeaderBoardRankWidget({
    super.key,
    required this.rank,
  });

  final int rank;

  @override
  Widget build(BuildContext context) {
    var rankEnum = ContestRankEnumExtension.rankToEnum(rank);
    return Container(
      padding: EdgeInsets.all(2.r),
      height: 24.h,
      width: 24.h,
      decoration: BoxDecoration(
        color: rankEnum.textBGColor,
        border: Border.all(color: rankEnum.textBorderColor, width: 2.w),
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Center(
          child: Text(
            rank.toString(),
            // "000",
            textAlign: TextAlign.center,

            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: rankEnum.textColor,
                ),
          ),
        ),
      ),
    );
  }
}

class _ReferralDescriptionRow extends StatelessWidget {
  final RankingDetail rankingDetail;

  const _ReferralDescriptionRow({required this.rankingDetail});

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: CustomTextNS(
                rankingDetail.title,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      height: 18 / 12,
                      letterSpacing: -0.24,
                      color: AppColors.n90,
                    ),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            rankingDetail.value.toString(),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 18 / 15,
                  letterSpacing: -0.24,
                  color: AppColors.n90,
                ),
          ),
        ]);
  }
}

class _LeaderboardWidget extends StatelessWidget {
  final bool isContestRunning;
  final ContestModel? contestData;
  final LeaderboardResponse? leaderboardData;
  final int? currentUserRank;

  const _LeaderboardWidget({
    required this.isContestRunning,
    required this.contestData,
    required this.leaderboardData,
    required this.currentUserRank,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Text(
            isContestRunning
                ? languageProvider.getMessage(
                    'contest_ranking', 'Contest Ranking')
                : languageProvider.getMessage('winners_list', 'Winners List'),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF101840),
                ),
          ),
        ),
        SizedBox(height: 20.h),
        ListView.separated(
          shrinkWrap: true,
          itemCount: leaderboardData?.leaderboard?.length ?? 0,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final entry = leaderboardData?.leaderboard?[index];
            return _LeaderboardListItem(
              rank: index + 1,
              isContestRunning: isContestRunning,
              isFirst: index == 0,
              isLast: index == (leaderboardData?.leaderboard?.length ?? 0) - 1,
              leaderboardEntry: entry,
              leaderboardData: leaderboardData,
            );
          },
          separatorBuilder: (context, index) {
            return Container(
                height: 1.h,
                color: AppColors.n40,
                margin: EdgeInsets.symmetric(horizontal: 20.w));
          },
        )
      ],
    );
  }
}

class _ContestRuleRow extends StatelessWidget {
  final Map<String, dynamic>? title;

  const _ContestRuleRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 12.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 4.w),
          Container(
            height: 4,
            width: 4,
            margin: EdgeInsets.only(
                top: 4.h), // Adjust this value to align with text baseline
            decoration: BoxDecoration(
              color: AppColors.n0,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: CustomTextNS(
              title,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 12.sp,
                  color: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}

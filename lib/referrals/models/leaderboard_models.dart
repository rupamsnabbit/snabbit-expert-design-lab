import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

enum PrizeType {
  topPrize,
  rankedPrize,
  noPrize,
}

PrizeType? _getPrizeTypeFromString(String? prizeTypeString) {
  switch (prizeTypeString?.toLowerCase()) {
    case 'top_prize':
      return PrizeType.topPrize;
    case 'ranked_prize':
      return PrizeType.rankedPrize;
    case 'no_prize':
      return PrizeType.noPrize;
    default:
      return PrizeType.noPrize;
  }
}

class LeaderboardEntry {
  int? id;
  String? name;
  String? publicPic;
  int? referralCount;
  int? order;
  WinningConfig? winningConfig;

  LeaderboardEntry({
    this.id,
    this.name,
    this.publicPic,
    this.referralCount,
    this.order,
    this.winningConfig,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> data) {
    return LeaderboardEntry(
      id: anyValueToInt(data['id']) ?? null,
      name: data['name'] ?? null,
      publicPic: data['public_pic'] ?? null,
      referralCount: anyValueToInt(data['referral_count']),
      order: anyValueToInt(data['order']),
      winningConfig: data['winning_config'] != null
          ? WinningConfig.fromMap(data['winning_config'])
          : null,
    );
  }
}

class RankingDetail {
  int? order;
  Map<String, dynamic>? title;
  String? value;

  RankingDetail({
    this.order,
    this.title,
    this.value,
  });

  factory RankingDetail.fromMap(Map<String, dynamic> data) {
    return RankingDetail(
      order: anyValueToInt(data['order']) ?? null,
      title: data['title'] ?? null,
      value: data['value'] ?? null,
    );
  }
}

class WinningConfig {
  List<RankingDetail>? rankingDetails;
  Map<String, dynamic>? title;
  Map<String, dynamic>? subTitle;
  RemoteImage? prizeImage;
  PrizeType? prizeType;
  Map<String, dynamic>? winningText;

  WinningConfig({
    this.rankingDetails,
    this.title,
    this.subTitle,
    this.prizeImage,
    this.prizeType,
    this.winningText,
  });

  factory WinningConfig.fromMap(Map<String, dynamic> data) {
    return WinningConfig(
      rankingDetails: data['ranking_details'] != null
          ? List<RankingDetail>.from(
              data['ranking_details'].map((e) => RankingDetail.fromMap(e)))
          : null,
      title: data['title'] ?? null,
      subTitle: data['sub_title'] ?? null,
      prizeImage: data['prize_image'] != null
          ? RemoteImage.fromJson(data['prize_image'])
          : null,
      prizeType: _getPrizeTypeFromString(data['prize_type']),
      winningText: data['winning_text'],
    );
  }
}

class ContestRankUpMessage {
  String? key;
  String? text;
  final Map<String, dynamic>? textData;

  ContestRankUpMessage({
    this.key,
    this.text,
    this.textData,
  });

  factory ContestRankUpMessage.fromMap(Map<String, dynamic> data) {
    return ContestRankUpMessage(
      key: data['key'],
      text: data['text'],
      textData: data['data'],
    );
  }
}

class LeaderboardResponse {
  int? id;
  List<LeaderboardEntry>? leaderboard;
  LeaderboardEntry? currentUser;
  final Map<String, dynamic>? contestRankUpMessage;

  LeaderboardResponse({
    this.id,
    this.leaderboard,
    this.currentUser,
    this.contestRankUpMessage,
  });

  factory LeaderboardResponse.fromMap(Map<String, dynamic> data) {
    return LeaderboardResponse(
      id: anyValueToInt(data['id']),
      leaderboard: data['leaderboard'] != null
          ? List<LeaderboardEntry>.from(
              data['leaderboard'].map((e) => LeaderboardEntry.fromMap(e)))
          : null,
      currentUser: data['current_user'] != null
          ? LeaderboardEntry.fromMap(data['current_user'])
          : null,
      contestRankUpMessage: data['contest_rank_up_message'] != null
          ? data['contest_rank_up_message']
          : null,
    );
  }
}

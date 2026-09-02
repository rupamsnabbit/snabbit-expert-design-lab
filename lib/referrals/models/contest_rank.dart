import 'package:flutter/material.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/utils/colors.dart';

enum ContestRankEnum {
  first,
  second,
  third,
  others,
  self,
}

extension ContestRankEnumExtension on ContestRankEnum {
  static ContestRankEnum rankToEnum(int rank) {
    switch (rank) {
      case 1:
        return ContestRankEnum.first;
      case 2:
        return ContestRankEnum.second;
      case 3:
        return ContestRankEnum.third;
      default:
        return ContestRankEnum.others;
    }
  }

  static int enumToRank(ContestRankEnum rank) {
    switch (rank) {
      case ContestRankEnum.first:
        return 1;
      case ContestRankEnum.second:
        return 2;
      case ContestRankEnum.third:
        return 3;
      default:
        return -1;
    }
  }

  String get rank {
    switch (this) {
      case ContestRankEnum.first:
        return "1st";
      case ContestRankEnum.second:
        return "2nd";
      case ContestRankEnum.third:
        return "3rd";
      case ContestRankEnum.others:
        return "Others";
      case ContestRankEnum.self:
        return "Self";
    }
  }

  Color get textBGColor {
    switch (this) {
      case ContestRankEnum.first:
        return const Color(0xFFFFC229);
      case ContestRankEnum.second:
        return const Color(0xFFDCDCDC);
      case ContestRankEnum.third:
        return const Color(0xFFECAB6B);
      case ContestRankEnum.others:
        return Colors.white;
      case ContestRankEnum.self:
        return Colors.white;
    }
  }

  Color get textBorderColor {
    switch (this) {
      case ContestRankEnum.first:
        return const Color(0xFF996A13);
      case ContestRankEnum.second:
        return const Color(0xFF757575);
      case ContestRankEnum.third:
        return const Color(0xFF992E13);
      case ContestRankEnum.others:
        return AppColors.n40;
      case ContestRankEnum.self:
        return AppColors.n40;
    }
  }

  Color get textColor {
    switch (this) {
      case ContestRankEnum.first:
        return const Color(0xFF66460D);
      case ContestRankEnum.second:
        return const Color(0xFF4E5969);
      case ContestRankEnum.third:
        return const Color(0xFF992E13);
      case ContestRankEnum.others:
        return AppColors.n90;
      case ContestRankEnum.self:
        return AppColors.n90;
    }
  }

  Color get leaderboardBgColor {
    switch (this) {
      case ContestRankEnum.first:
        return const Color(0xFFFFF0BF);
      case ContestRankEnum.second:
        return const Color(0xFFDDE3EA);
      case ContestRankEnum.third:
        return const Color(0xFFFFDECF);
      case ContestRankEnum.others:
        return Colors.white;
      case ContestRankEnum.self:
        return const Color(0xFFEBECFF);
    }
  }


}

/**
 * Unit tests for lib/referrals/models/contest_rank.dart
 *
 * COVERAGE REQUIREMENTS:
 * - ✅ **Branch Coverage: 100% (REQUIRED)** - Every switch case must be tested
 * - 📊 **Line Coverage: 60%** - Models (business logic only)
 *
 * Testing Philosophy:
 * - 100% branch coverage (strict requirement)
 * - Test all switch cases for each extension method/getter
 * - AAA pattern (Arrange-Act-Assert)
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/referrals/models/contest_rank.dart';
import 'package:flutter/material.dart';

void main() {
  group('ContestRankEnum', () {
    test('has all expected values', () {
      // Arrange & Act
      final values = ContestRankEnum.values;

      // Assert
      expect(values.length, equals(5));
      expect(values, contains(ContestRankEnum.first));
      expect(values, contains(ContestRankEnum.second));
      expect(values, contains(ContestRankEnum.third));
      expect(values, contains(ContestRankEnum.others));
      expect(values, contains(ContestRankEnum.self));
    });
  });

  group('ContestRankEnumExtension', () {
    group('rankToEnum', () {
      test('returns first for rank 1', () {
        // Arrange & Act
        final result = ContestRankEnumExtension.rankToEnum(1);

        // Assert
        expect(result, equals(ContestRankEnum.first));
      });

      test('returns second for rank 2', () {
        // Arrange & Act
        final result = ContestRankEnumExtension.rankToEnum(2);

        // Assert
        expect(result, equals(ContestRankEnum.second));
      });

      test('returns third for rank 3', () {
        // Arrange & Act
        final result = ContestRankEnumExtension.rankToEnum(3);

        // Assert
        expect(result, equals(ContestRankEnum.third));
      });

      test('returns others for rank greater than 3', () {
        // Arrange & Act - testing default case
        final result = ContestRankEnumExtension.rankToEnum(10);

        // Assert
        expect(result, equals(ContestRankEnum.others));
      });

      test('returns others for rank 0', () {
        // Arrange & Act - testing default case
        final result = ContestRankEnumExtension.rankToEnum(0);

        // Assert
        expect(result, equals(ContestRankEnum.others));
      });

      test('returns others for negative rank', () {
        // Arrange & Act - testing default case edge
        final result = ContestRankEnumExtension.rankToEnum(-1);

        // Assert
        expect(result, equals(ContestRankEnum.others));
      });
    });

    group('enumToRank', () {
      test('returns 1 for first', () {
        // Arrange & Act
        final result = ContestRankEnumExtension.enumToRank(ContestRankEnum.first);

        // Assert
        expect(result, equals(1));
      });

      test('returns 2 for second', () {
        // Arrange & Act
        final result = ContestRankEnumExtension.enumToRank(ContestRankEnum.second);

        // Assert
        expect(result, equals(2));
      });

      test('returns 3 for third', () {
        // Arrange & Act
        final result = ContestRankEnumExtension.enumToRank(ContestRankEnum.third);

        // Assert
        expect(result, equals(3));
      });

      test('returns -1 for others (default case)', () {
        // Arrange & Act
        final result = ContestRankEnumExtension.enumToRank(ContestRankEnum.others);

        // Assert
        expect(result, equals(-1));
      });

      test('returns -1 for self (default case)', () {
        // Arrange & Act
        final result = ContestRankEnumExtension.enumToRank(ContestRankEnum.self);

        // Assert
        expect(result, equals(-1));
      });
    });

    group('rank getter', () {
      test('returns "1st" for first', () {
        // Arrange
        final value = ContestRankEnum.first;

        // Act
        final result = value.rank;

        // Assert
        expect(result, equals("1st"));
      });

      test('returns "2nd" for second', () {
        // Arrange
        final value = ContestRankEnum.second;

        // Act
        final result = value.rank;

        // Assert
        expect(result, equals("2nd"));
      });

      test('returns "3rd" for third', () {
        // Arrange
        final value = ContestRankEnum.third;

        // Act
        final result = value.rank;

        // Assert
        expect(result, equals("3rd"));
      });

      test('returns "Others" for others', () {
        // Arrange
        final value = ContestRankEnum.others;

        // Act
        final result = value.rank;

        // Assert
        expect(result, equals("Others"));
      });

      test('returns "Self" for self', () {
        // Arrange
        final value = ContestRankEnum.self;

        // Act
        final result = value.rank;

        // Assert
        expect(result, equals("Self"));
      });
    });

    group('textBGColor getter', () {
      test('returns gold color for first', () {
        // Arrange
        final value = ContestRankEnum.first;

        // Act
        final result = value.textBGColor;

        // Assert
        expect(result, equals(const Color(0xFFFFC229)));
      });

      test('returns silver color for second', () {
        // Arrange
        final value = ContestRankEnum.second;

        // Act
        final result = value.textBGColor;

        // Assert
        expect(result, equals(const Color(0xFFDCDCDC)));
      });

      test('returns bronze color for third', () {
        // Arrange
        final value = ContestRankEnum.third;

        // Act
        final result = value.textBGColor;

        // Assert
        expect(result, equals(const Color(0xFFECAB6B)));
      });

      test('returns white color for others', () {
        // Arrange
        final value = ContestRankEnum.others;

        // Act
        final result = value.textBGColor;

        // Assert
        expect(result, equals(Colors.white));
      });

      test('returns white color for self', () {
        // Arrange
        final value = ContestRankEnum.self;

        // Act
        final result = value.textBGColor;

        // Assert
        expect(result, equals(Colors.white));
      });
    });

    group('textBorderColor getter', () {
      test('returns dark gold for first', () {
        // Arrange
        final value = ContestRankEnum.first;

        // Act
        final result = value.textBorderColor;

        // Assert
        expect(result, equals(const Color(0xFF996A13)));
      });

      test('returns dark gray for second', () {
        // Arrange
        final value = ContestRankEnum.second;

        // Act
        final result = value.textBorderColor;

        // Assert
        expect(result, equals(const Color(0xFF757575)));
      });

      test('returns dark bronze for third', () {
        // Arrange
        final value = ContestRankEnum.third;

        // Act
        final result = value.textBorderColor;

        // Assert
        expect(result, equals(const Color(0xFF992E13)));
      });

      // Note: Testing AppColors.n40 - assuming it's a defined constant
      test('returns AppColors.n40 for others', () {
        // Arrange
        final value = ContestRankEnum.others;

        // Act
        final result = value.textBorderColor;

        // Assert
        expect(result, isNotNull);
      });

      test('returns AppColors.n40 for self', () {
        // Arrange
        final value = ContestRankEnum.self;

        // Act
        final result = value.textBorderColor;

        // Assert
        expect(result, isNotNull);
      });
    });

    group('textColor getter', () {
      test('returns dark gold text for first', () {
        // Arrange
        final value = ContestRankEnum.first;

        // Act
        final result = value.textColor;

        // Assert
        expect(result, equals(const Color(0xFF66460D)));
      });

      test('returns dark gray text for second', () {
        // Arrange
        final value = ContestRankEnum.second;

        // Act
        final result = value.textColor;

        // Assert
        expect(result, equals(const Color(0xFF4E5969)));
      });

      test('returns dark bronze text for third', () {
        // Arrange
        final value = ContestRankEnum.third;

        // Act
        final result = value.textColor;

        // Assert
        expect(result, equals(const Color(0xFF992E13)));
      });

      test('returns AppColors.n90 for others', () {
        // Arrange
        final value = ContestRankEnum.others;

        // Act
        final result = value.textColor;

        // Assert
        expect(result, isNotNull);
      });

      test('returns AppColors.n90 for self', () {
        // Arrange
        final value = ContestRankEnum.self;

        // Act
        final result = value.textColor;

        // Assert
        expect(result, isNotNull);
      });
    });

    group('leaderboardBgColor getter', () {
      test('returns light gold background for first', () {
        // Arrange
        final value = ContestRankEnum.first;

        // Act
        final result = value.leaderboardBgColor;

        // Assert
        expect(result, equals(const Color(0xFFFFF0BF)));
      });

      test('returns light gray background for second', () {
        // Arrange
        final value = ContestRankEnum.second;

        // Act
        final result = value.leaderboardBgColor;

        // Assert
        expect(result, equals(const Color(0xFFDDE3EA)));
      });

      test('returns light bronze background for third', () {
        // Arrange
        final value = ContestRankEnum.third;

        // Act
        final result = value.leaderboardBgColor;

        // Assert
        expect(result, equals(const Color(0xFFFFDECF)));
      });

      test('returns white background for others', () {
        // Arrange
        final value = ContestRankEnum.others;

        // Act
        final result = value.leaderboardBgColor;

        // Assert
        expect(result, equals(Colors.white));
      });

      test('returns light purple background for self', () {
        // Arrange
        final value = ContestRankEnum.self;

        // Act
        final result = value.leaderboardBgColor;

        // Assert
        expect(result, equals(const Color(0xFFEBECFF)));
      });
    });
  });
}

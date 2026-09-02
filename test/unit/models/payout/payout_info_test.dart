import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/models/payout/payout_info.dart';

void main() {
  group('PayoutInfo.fromDynamic', () {
    test('returns empty when raw is null', () {
      final info = PayoutInfo.fromDynamic(null);
      expect(info.totalEarning, isNull);
      expect(info.breakdown, isEmpty);
      expect(info.hasCheckInRow, isFalse);
    });

    test('returns empty when raw is not a map', () {
      final info = PayoutInfo.fromDynamic('not a map');
      expect(info.totalEarning, isNull);
      expect(info.breakdown, isEmpty);
    });

    test('parses total_earning + empty breakdown', () {
      final info = PayoutInfo.fromDynamic({
        'total_earning': 210,
        'breakdown': [],
      });
      expect(info.totalEarning, 210);
      expect(info.breakdown, isEmpty);
    });

    test('parses breakdown rows', () {
      final info = PayoutInfo.fromDynamic({
        'total_earning': 350,
        'breakdown': [
          {
            'title': {'key': 'work', 'default_text': 'Work'},
            'pill_text': '1 hr',
            'amount': 250,
          },
          {
            'title': {'key': 'ot_label', 'default_text': 'OT'},
            'pill_text': '15 min',
            'icon_url': 'https://example.com/ot.png',
            'amount': 50,
          },
        ],
      });

      expect(info.breakdown, hasLength(2));
      expect(info.breakdown[0].title.key, 'work');
      expect(info.breakdown[0].title.defaultText, 'Work');
      expect(info.breakdown[0].pillText, '1 hr');
      expect(info.breakdown[0].iconUrl, isNull);
      expect(info.breakdown[0].amount, 250);

      expect(info.breakdown[1].iconUrl, 'https://example.com/ot.png');
    });

    test('breakdown is empty when "breakdown" is missing or wrong type', () {
      expect(PayoutInfo.fromDynamic({'total_earning': 1}).breakdown, isEmpty);
      expect(
        PayoutInfo.fromDynamic({'breakdown': 'not a list'}).breakdown,
        isEmpty,
      );
    });

    test('parses check-in fields when present', () {
      final info = PayoutInfo.fromDynamic({
        'total_earning': 210,
        'breakdown': [],
        'check_in_amount': 30,
        'check_in_time': '2030-06-15T19:45:00.000+05:30',
        'actual_check_in_time': '2030-06-15T19:43:00.000+05:30',
      });
      expect(info.checkInAmount, 30);
      expect(info.checkInTime, isNotNull);
      expect(info.actualCheckInTime, isNotNull);
      expect(info.hasCheckInRow, isTrue);
    });

    test('actualCheckInTime null when not provided', () {
      final info = PayoutInfo.fromDynamic({
        'total_earning': 210,
        'check_in_amount': 30,
        'check_in_time': '2030-06-15T19:45:00.000+05:30',
      });
      expect(info.actualCheckInTime, isNull);
    });

    test('amount: 0 is preserved (not treated as null)', () {
      final info = PayoutInfo.fromDynamic({
        'breakdown': [
          {
            'title': {'key': 'free_row', 'default_text': 'Free'},
            'amount': 0,
          },
        ],
      });
      expect(info.breakdown.single.amount, 0);
    });

    test('row missing title returns empty NudgeLabel', () {
      final info = PayoutInfo.fromDynamic({
        'breakdown': [
          {'amount': 10},
        ],
      });
      expect(info.breakdown.single.title.key, isEmpty);
    });

    test('parses subtitle when present', () {
      final info = PayoutInfo.fromDynamic({
        'breakdown': [
          {
            'title': {'key': 'work', 'default_text': 'Work'},
            'subtitle': {
              'key': 'work_sub',
              'default_text': 'Includes **OT**',
            },
            'amount': 250,
          },
        ],
      });
      final line = info.breakdown.single;
      expect(line.subtitle, isNotNull);
      expect(line.subtitle!.key, 'work_sub');
      expect(line.subtitle!.defaultText, 'Includes **OT**');
    });

    test('subtitle is null when absent', () {
      final info = PayoutInfo.fromDynamic({
        'breakdown': [
          {
            'title': {'key': 'work', 'default_text': 'Work'},
            'amount': 250,
          },
        ],
      });
      expect(info.breakdown.single.subtitle, isNull);
    });

    test('subtitle is null when wrong type', () {
      final info = PayoutInfo.fromDynamic({
        'breakdown': [
          {
            'title': {'key': 'work', 'default_text': 'Work'},
            'subtitle': 'not a map',
            'amount': 250,
          },
        ],
      });
      expect(info.breakdown.single.subtitle, isNull);
    });
  });

  group('PayoutLine.fromDynamic', () {
    test('returns blank line when raw is not a map', () {
      final line = PayoutLine.fromDynamic('nope');
      expect(line.title.key, isEmpty);
      expect(line.amount, isNull);
      expect(line.subtitle, isNull);
    });
  });
}
